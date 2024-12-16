class Asset < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true
  belongs_to :user, optional: true

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true, format: { with: URI.regexp(%w[http https]), message: "must be a valid URL" }
  validates :category, inclusion: { in: %w[profile banner merit wish thank] }
  validates :format, inclusion: { in: %w[image video doc unknown] }
  validates :source, inclusion: { in: %w[google upload] }
  validates :size, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_extension_and_format

  private

  def set_extension_and_format
    self.extension = File.extname(URI.parse(url).path).delete(".")
    if format.blank?
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
    end
  end
end
