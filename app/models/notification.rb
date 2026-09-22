require "uri"

# app/models/notification.rb
class Notification < ApplicationRecord
  self.table_name = "notifications"

  # ===== ASSOCIATIONS =====
  has_many :user_notifications, dependent: :nullify

  # ===== VALIDATIONS =====
  validates :event, presence: true,
                    uniqueness: { conditions: -> { kept } },
                    format: { with: NotificationConstants::Event::FORMAT }
  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: NotificationConstants::Category::ALL }
  validate :clients_are_valid
  validate :link_is_supported_destination

  # ===== SCOPES =====
  scope :for_category, ->(cat) { where(category: cat) }
  scope :for_admin, -> { where(admin: true) }
  scope :for_client, ->(client) { where("clients @> ARRAY[?]::varchar[]", client.to_s) }

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

  private

  def clients_are_valid
    valid = clients.is_a?(Array) && clients.present? && clients.uniq == clients &&
      clients.all? { |client| client.match?(NotificationConstants::Client::FORMAT) }
    return if valid

    errors.add(:clients, :invalid)
  end

  def link_is_supported_destination
    return if link.blank? || link.in?(NotificationConstants::Link::TEMPLATE_LINKS)

    uri = URI.parse(link)
    return if uri.is_a?(URI::HTTPS) && uri.host.present?

    errors.add(:link, :invalid)
  rescue URI::InvalidURIError
    errors.add(:link, :invalid)
  end
end
