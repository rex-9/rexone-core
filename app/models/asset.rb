class Asset < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true
  belongs_to :user, optional: true

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[profile banner merit wish thank] }
  validates :format, inclusion: { in: %w[image video doc unknown] }
  validates :source, inclusion: { in: %w[google upload] }
  validates :size, numericality: { greater_than_or_equal_to: 0 }

  validate :url_must_be_valid

  before_validation :set_extension_and_format

  private

	def url_must_be_valid
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
                  when "jpg", "jpeg", "png", "gif"
                    "image"
                  when "mp4", "mov", "avi"
                    "video"
                  when "pdf", "doc", "docx"
                    "doc"
                  else
                    "unknown"
                  end
  rescue URI::InvalidURIError
    self.extension = nil
    self.format ||= "unknown"
  end
end