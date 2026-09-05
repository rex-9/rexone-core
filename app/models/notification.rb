# app/models/notification.rb
class Notification < ApplicationRecord
  self.table_name = "notifications"

  # ===== ASSOCIATIONS =====
  has_many :user_notifications, dependent: :nullify

  # ===== VALIDATIONS =====
  validates :event, presence: true, uniqueness: { conditions: -> { kept } }
  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: NotificationConstants::Category::ALL }

  # ===== SCOPES =====
  scope :for_category, ->(cat) { where(category: cat) }
  scope :for_admin, -> { where(admin: true) }

  # ===== TEMPLATE INTERPOLATION =====
  def render_text(text, user: nil, context: {})
    return "" if text.blank?

    interpolated = text.dup
    replacements = {
      "user_name" => user&.name.presence || user&.username.presence || "User",
      "user_email" => user&.email.to_s
    }.merge(context.stringify_keys)

    replacements.each do |key, val|
      interpolated.gsub!("{{#{key}}}", val.to_s)
    end

    interpolated
  end
end
