# app/models/notification.rb

class Notification < ApplicationRecord
  self.primary_key = "id"

  belongs_to :user

  validates :message, presence: true, length: { maximum: 5000 }
  validates :title, length: { maximum: 255 }, allow_blank: true
  validates :data, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
    self
  end
end
