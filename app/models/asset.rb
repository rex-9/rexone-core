# app/models/asset.rb

class Asset < ApplicationRecord
  LOG_PREFIX = "[Asset]".freeze

  self.inheritance_column = nil

  belongs_to :resource, polymorphic: true, foreign_type: :resource_model, optional: true

  validates :name, presence: true
  validates :url, presence: true, uniqueness: true
  validates :type, inclusion: { in: AssetConstants::AssetType::ALL }
  validates :format, inclusion: { in: AssetConstants::AssetFormat::ALL }, allow_nil: true
  validates :source, inclusion: { in: [ AssetConstants::AssetSource::UPLOAD, AssetConstants::AssetSource::GOOGLE ] }
  validates :size_bytes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_secs, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :storage_key, presence: true, if: :uploaded?
  validates :resource_model, presence: true, if: -> { resource_id.present? }
  validates :resource_id, presence: true, if: -> { resource_model.present? }
  validate :url_must_be_valid
  before_validation :normalize_resource_model
  before_validation :set_extension_and_format
  after_destroy_commit :delete_from_storage_later, if: :uploaded_file?

  scope :uploaded, -> { where(source: AssetConstants::AssetSource::UPLOAD) }
  scope :google, -> { where(source: AssetConstants::AssetSource::GOOGLE) }
  scope :for_resource, ->(model, id) { where(resource_model: model.to_s.downcase, resource_id: id) }

  def resource
    return nil if resource_model.blank? || resource_id.blank?

    resource_model.classify.constantize.find_by(id: resource_id)
  rescue NameError
    nil
  end

  def resource=(record)
    if record.present?
      self.resource_model = record.model_name.singular
      self.resource_id = record.id
    else
      self.resource_model = nil
      self.resource_id = nil
    end
  end

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

  def uploaded?
    source == AssetConstants::AssetSource::UPLOAD
  end

  def uploaded_file?
    source == AssetConstants::AssetSource::UPLOAD && storage_key.present?
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
    case format
    when AssetConstants::AssetFormat::VIDEO, AssetConstants::AssetFormat::AUDIO
      "video"
    when AssetConstants::AssetFormat::DOC
      "raw"
    else
      AssetConstants::AssetFormat::IMAGE
    end
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

  def normalize_resource_model
    self.resource_model = resource_model.to_s.underscore if resource_model.present?
  end

  def set_extension_and_format
    return if url.blank?

    self.extension = File.extname(URI.parse(url).path).delete(".")
    self.extension = nil if extension.blank?

    return if format.present?

    self.format = case extension.to_s.downcase
    when "jpg", "jpeg", "png", "gif", "webp", "svg"
      AssetConstants::AssetFormat::IMAGE
    when "mp3", "wav", "m4a", "aac", "ogg", "flac"
      AssetConstants::AssetFormat::AUDIO
    when "mp4", "mov", "avi", "webm", "mkv"
      AssetConstants::AssetFormat::VIDEO
    when "pdf", "doc", "docx", "txt", "rtf"
      AssetConstants::AssetFormat::DOC
    else
      nil
    end
  rescue URI::InvalidURIError
    self.extension = nil
    self.format = nil
  end
end
