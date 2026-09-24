# app/models/asset.rb

class Asset < ApplicationRecord
  LOG_PREFIX = "[Asset]".freeze

  self.inheritance_column = nil

  belongs_to :assetable, polymorphic: true, optional: true
  belongs_to :parent_asset, class_name: "Asset", optional: true
  has_one :thumbnail,
          -> { where(type: AssetConstants::AssetType::THUMBNAIL) },
          class_name: "Asset",
          foreign_key: :parent_asset_id,
          dependent: :destroy,
          inverse_of: :parent_asset
  has_many :subtitles,
           -> { where(type: AssetConstants::AssetType::SUBTITLE).order(created_at: :asc) },
           class_name: "Asset",
           foreign_key: :parent_asset_id,
           dependent: :destroy,
           inverse_of: :parent_asset

  validates :name, presence: true
  validates :url, presence: true, uniqueness: true
  validates :type, inclusion: { in: AssetConstants::AssetType::ALL }
  validates :format, inclusion: { in: AssetConstants::AssetFormat::ALL }, allow_nil: true
  validates :source, inclusion: { in: [ AssetConstants::AssetSource::UPLOAD, AssetConstants::AssetSource::GOOGLE ] }
  validates :size_bytes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_secs, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, inclusion: { in: MediaConstants::Status::ALL }
  validates :storage_key, presence: true, if: :uploaded?
  validates :assetable_type, presence: true, if: -> { assetable_id.present? }
  validates :assetable_id, presence: true, if: -> { assetable_type.present? }
  validate :url_must_be_valid
  validate :only_one_thumbnail_per_parent
  validate :child_asset_type_immutable, on: :update
  validate :parent_asset_validations

  before_validation :set_default_title
  before_validation :set_extension_and_format
  after_destroy_commit :delete_from_storage, if: :uploaded_file?

  scope :uploaded, -> { where(source: AssetConstants::AssetSource::UPLOAD) }
  scope :google, -> { where(source: AssetConstants::AssetSource::GOOGLE) }
  scope :for_resource, ->(model, id) { where(assetable_type: model.to_s, assetable_id: id) }
  scope :ready, -> { where(status: MediaConstants::Status::READY) }
  scope :optimal, -> { where(status: MediaConstants::Status::OPTIMAL) }
  scope :processing, -> { where(status: MediaConstants::Status::PROCESSING) }
  scope :failed, -> { where(status: MediaConstants::Status::FAILED) }

  def delete_from_storage
    return unless storage_key.present?

    StorageService::Client.delete(
      storage_key,
      resource_type: storage_resource_type
    )
    Rails.logger.info("#{LOG_PREFIX} Deleted from storage: #{storage_key}")
  rescue StandardError => e
    Rails.error.report(e)
    Rails.logger.error("#{LOG_PREFIX} Failed to delete from storage: #{e.message}")
  end

  def self.purge_and_destroy_all!(scope)
    scope.find_each(&:destroy)
  end

  def uploaded?
    source == AssetConstants::AssetSource::UPLOAD
  end

  def uploaded_file?
    storage_key.present?
  end

  def display_name
    title.presence || name
  end

  def storage_url(options = {})
    return url unless uploaded_file? && storage_key.present?

    opts = options.dup
    if extension.present? && !opts.key?(:response_content_type)
      mime = Rack::Mime.mime_type(".#{extension}", nil)
      opts[:response_content_type] = mime if mime
    end
    opts[:response_content_disposition] ||= "inline"

    StorageService::Client.url(storage_key, opts)
  end

  def refresh_url
    return unless uploaded_file? && storage_key.present?

    new_url = StorageService::Client.url(storage_key)
    update_column(:url, new_url) if new_url.present?
  rescue StorageService::Error => e
    Rails.logger.error("#{LOG_PREFIX} Failed to refresh URL: #{e.message}")
    false
  end

  def compressible?
    !max_compressed? && (compressible_video? || compressible_image? || compressible_audio?)
  end

  def compressible_video?
    MediaConstants::Processing::COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::VIDEO).include?(extension&.downcase)
  end

  def compressible_image?
    MediaConstants::Processing::COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::IMAGE).include?(extension&.downcase)
  end

  def compressible_audio?
    MediaConstants::Processing::COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::AUDIO).include?(extension&.downcase)
  end

  def thumbnail_attachable?
    thumbnail_generatable? || compressible_audio?
  end

  def thumbnail_generatable?
    MediaConstants::Processing::THUMBNAIL_GENERATION_EXTENSIONS.include?(extension&.downcase)
  end

  def image_convertible?
    MediaConstants::Processing::IMAGE_CONVERSION_EXTENSIONS.include?(extension&.downcase)
  end

  def subtitle_attachable?
    compressible_video? || compressible_audio?
  end

  def playable?
    playable_format? && playable_status? && storage_key.present?
  end

  def playable_format?
    MediaConstants::Playback::PLAYABLE_FORMATS.include?(format)
  end

  def playable_status?
    MediaConstants::Playback::PLAYABLE_STATUSES.include?(status)
  end

  def mime_type
    Rack::Mime.mime_type(".#{extension}", "application/octet-stream")
  end

  def pending?
    status == MediaConstants::Status::PENDING
  end

  def processing?
    status == MediaConstants::Status::PROCESSING
  end

  def ready?
    status == MediaConstants::Status::READY
  end

  def optimal?
    status == MediaConstants::Status::OPTIMAL
  end

  def failed?
    status == MediaConstants::Status::FAILED
  end

  def compression_count
    return MediaConstants::MAX_COMPRESSION_PASSES if optimal?

    CacheService.read(compression_cache_key).to_i
  end

  def increment_compression_count!
    new_val = compression_count + 1
    CacheService.write(compression_cache_key, new_val)
    new_val
  end

  def clear_compression_count!
    CacheService.delete(compression_cache_key)
  end

  def max_compressed?
    optimal? || compression_count >= MediaConstants::MAX_COMPRESSION_PASSES
  end

  def mark_processing!
    update!(status: MediaConstants::Status::PROCESSING)
  end

  def mark_ready!
    update!(status: MediaConstants::Status::READY)
  end

  def mark_optimal!
    clear_compression_count!
    update!(status: MediaConstants::Status::OPTIMAL)
  end

  def mark_failed!
    update!(status: MediaConstants::Status::FAILED)
  end

  private

  def compression_cache_key
    "asset_compression_count:#{id}"
  end

  def only_one_thumbnail_per_parent
    return unless parent_asset_id.present? && type == AssetConstants::AssetType::THUMBNAIL

    duplicate = Asset.where(parent_asset_id: parent_asset_id, type: AssetConstants::AssetType::THUMBNAIL)
    duplicate = duplicate.where.not(id: id) if persisted?
    errors.add(:type, :thumbnail_exists_for_parent) if duplicate.exists?
  end

  def child_asset_type_immutable
    if parent_asset_id_was.present? && type_changed?
      errors.add(:type, "Child asset type cannot be changed")
    end
  end

  def parent_asset_validations
    return unless parent_asset_id.present?

    if parent_asset_id == id
      errors.add(:parent_asset_id, "cannot be itself")
    elsif parent_asset&.parent_asset_id.present?
      errors.add(:parent_asset_id, "cannot be a child asset")
    elsif (thumbnail.present? || subtitles.any?) && parent_asset_id.present?
      errors.add(:parent_asset_id, "asset with existing children cannot become a child asset")
    end
  end

  def storage_resource_type
    AssetConstants::AssetFormat.storage_resource_type(extension)
  end

  def url_must_be_valid
    return if url.blank?

    uri = URI.parse(url)

    unless uri.is_a?(URI::HTTP) && uri.host.present?
      errors.add(:url, :invalid_url)
    end
  rescue URI::InvalidURIError
    errors.add(:url, :invalid_url)
  end

  def set_extension_and_format
    return if url.blank?

    if extension.blank?
      ext = File.extname(URI.parse(url).path).delete(".").downcase
      self.extension = ext.presence
    end

    return if format.present?

    self.format = AssetConstants::AssetFormat.from_extension(extension)
    if format.blank? && (google_user_content_url? || (extension.blank? && image_type?))
      self.format = AssetConstants::AssetFormat::IMAGE
    end
  rescue URI::InvalidURIError
    self.extension = nil if extension.blank?
    self.format = nil if format.blank?
  end

  def google_user_content_url?
    url.to_s.include?("googleusercontent.com")
  end

  def image_type?
    AssetConstants::AssetType::IMAGE_TYPES.include?(type)
  end

  def set_default_title
    self.title = name if title.blank? && name.present?
  end
end
