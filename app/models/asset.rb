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
  validates :storage_key, presence: true, if: :uploaded?
  validates :assetable_type, presence: true, if: -> { assetable_id.present? }
  validates :assetable_id, presence: true, if: -> { assetable_type.present? }
  validate :url_must_be_valid
  before_validation :set_extension_and_format
  after_destroy_commit :delete_from_storage_later, if: :uploaded_file?

  scope :uploaded, -> { where(source: AssetConstants::AssetSource::UPLOAD) }
  scope :google, -> { where(source: AssetConstants::AssetSource::GOOGLE) }
  scope :for_resource, ->(model, id) { where(assetable_type: model.to_s, assetable_id: id) }

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

    StorageService::Client.url(storage_key, options)
  end

  def refresh_url
    return unless uploaded_file? && storage_key.present?

    new_url = StorageService::Client.url(storage_key)
    update_column(:url, new_url) if new_url.present?
  rescue StorageService::Error => e
    Rails.logger.error("#{LOG_PREFIX} Failed to refresh URL: #{e.message}")
    false
  end

  private

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
