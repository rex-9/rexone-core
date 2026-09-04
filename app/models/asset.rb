# app/models/asset.rb

class Asset < ApplicationRecord
  LOG_PREFIX = "[Asset]".freeze

  self.inheritance_column = nil

  belongs_to :assetable, polymorphic: true, optional: true

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
  before_validation :set_extension_and_format
  after_destroy_commit :delete_from_storage_later, if: :uploaded_file?

  scope :uploaded, -> { where(source: AssetConstants::AssetSource::UPLOAD) }
  scope :google, -> { where(source: AssetConstants::AssetSource::GOOGLE) }
  scope :for_resource, ->(model, id) { where(assetable_type: model.to_s, assetable_id: id) }
  scope :ready, -> { where(status: MediaConstants::Status::READY) }
  scope :optimal, -> { where(status: MediaConstants::Status::OPTIMAL) }
  scope :processing, -> { where(status: MediaConstants::Status::PROCESSING) }
  scope :failed, -> { where(status: MediaConstants::Status::FAILED) }

  def delete_from_storage_later
    return unless storage_key.present?

    StorageService::Client.delete_later(
      storage_key,
      resource_type: storage_resource_type
    )
    Rails.logger.info("#{LOG_PREFIX} Queued storage deletion: #{storage_key}")
  rescue StandardError => e
    Rails.error.report(e)
    Rails.logger.error("#{LOG_PREFIX} Failed to queue storage deletion: #{e.message}")
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

  def generate_storage_key
    return storage_key if storage_key.present?

    self.storage_key = "#{type}/#{name}_#{Time.now.to_i}"
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
    !max_compressed? && (compressible_video? || compressible_image?)
  end

  def compressible_video?
    MediaConstants::COMPRESSIBLE_VIDEO_EXTENSIONS.include?(extension&.downcase)
  end

  def compressible_image?
    MediaConstants::COMPRESSIBLE_IMAGE_EXTENSIONS.include?(extension&.downcase)
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

  def storage_resource_type
    AssetConstants::AssetFormat.storage_resource_type(extension)
  end

  def url_must_be_valid
    return if url.blank?

    uri = URI.parse(url)

    unless uri.is_a?(URI::HTTP) && uri.host.present?
      errors.add(:url, "must be a valid URL")
    end
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid URL")
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
end
