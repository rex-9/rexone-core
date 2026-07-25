# app/models/access.rb
class Access < ApplicationRecord
  # ===== ASSOCIATIONS =====
  belongs_to :user
  belongs_to :product, class_name: "Payment::Product"

  # ===== ENUMS =====
  enum :status, {
    active: "active",
    expired: "expired",
    revoked: "revoked"
  }

  # ===== VALIDATIONS =====
  validates :granted_at, presence: true

  # ===== SCOPES =====
  scope :active, -> { where(status: "active") }
  scope :expired, -> { where(status: "expired") }
  scope :revoked, -> { where(status: "revoked") }
  scope :expiring_soon, -> { active.where("expires_at < ?", 7.days.from_now) }

  # ===== INSTANCE METHODS =====
  def active?
    status == "active" && (expires_at.nil? || expires_at > Time.current)
  end

  def expired?
    status == "expired" || (expires_at.present? && expires_at < Time.current)
  end

  def revoke!
    update(status: "revoked", revoked_at: Time.current)
  end

  def expire!
    update(status: "expired", expired_at: Time.current)
  end

  def days_remaining
    return nil if expires_at.nil?
    ((expires_at - Time.current) / 1.day).ceil
  end

  def display_expiry
    return "Never" if expires_at.nil?
    expires_at.strftime("%b %d, %Y")
  end
end
