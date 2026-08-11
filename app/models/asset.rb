# app/models/asset.rb

class Asset < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true
  belongs_to :user, optional: true

  validates :name, presence: true, uniqueness: { scope: :user_id }  # Allow same name for different users
  validates :url, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[profile banner] }
  validates :format, inclusion: { in: %w[image video doc unknown] }
  validates :source, inclusion: { in: %w[google upload] }
  validates :size, numericality: { greater_than_or_equal_to: 0 }
  validates :public_id, presence: true, if: :uploaded?  # Only required for uploaded files

  validate :url_must_be_valid

  before_validation :set_extension_and_format
  before_destroy :delete_from_storage, if: :uploaded_file?

  scope :uploaded, -> { where(source: "upload") }
  scope :google, -> { where(source: "google") }

  def delete_from_storage
    return unless public_id.present?

    begin
      StorageService::Client.delete(public_id, resource_type: format)
      Rails.logger.info("[Asset] Deleted from storage: #{public_id}")
    rescue StorageService::Error => e
      Rails.logger.error("[Asset] Failed to delete from storage: #{e.message}")
      # Don't raise, just log - we still want to delete the database record
    end
  end

  def uploaded?
    source == "upload"
  end

  def uploaded_file?
    source == "upload" && public_id.present?
  end

  def generate_public_id
    return public_id if public_id.present?

    self.public_id = "#{category}/#{name}_#{Time.now.to_i}"
  end

  def storage_url(options = {})
    return url unless uploaded_file? && public_id.present?

    StorageService::Client.url(public_id, options)
  end

  def refresh_url
    return unless uploaded_file? && public_id.present?

    new_url = StorageService::Client.url(public_id)
    update_column(:url, new_url) if new_url.present?
  rescue StorageService::Error => e
    Rails.logger.error("[Asset] Failed to refresh URL: #{e.message}")
    false
  end

  private

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

    self.extension = File.extname(URI.parse(url).path).delete(".")

    return unless format.blank?

    self.format = case extension.downcase
    when "jpg", "jpeg", "png", "gif", "webp", "svg"
                    "image"
    when "mp4", "mov", "avi", "webm", "mkv"
                    "video"
    when "pdf", "doc", "docx", "txt", "rtf"
                    "doc"
    else
                    "unknown"
    end
  rescue URI::InvalidURIError
    self.extension = nil
    self.format ||= "unknown"
  end
end
