# app/models/log_client.rb
class Log::Client < ApplicationRecord
  self.table_name = "log_clients"

  # ===== ENUMS =====
  enum :severity, {
    debug: "debug",
    info: "info",
    warning: "warning",
    error: "error",
    critical: "critical"
  }, prefix: :client_severity

  enum :platform, {
    web: "web",
    ios: "ios",
    android: "android"
  }, prefix: :client_platform

  enum :environment, {
    development: "development",
    staging: "staging",
    production: "production"
  }, prefix: :client_environment

  # ===== ASSOCIATIONS =====
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  # ===== VALIDATIONS =====
  validates :message, presence: true
  validates :severity, presence: true

  # ===== SCOPES =====
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :by_environment, ->(environment) { where(environment: environment) }
  scope :unresolved, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :unauthenticated, -> { where(user_id: nil) }
  scope :authenticated, -> { where.not(user_id: nil) }
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :for_today, -> { where("created_at >= ?", Time.current.beginning_of_day) }
  scope :with_storage_issues, -> { where("local_storage_keys != '[]' OR session_storage_keys != '[]'") }

  # ===== INSTANCE METHODS =====
  def resolved?
    resolved_at.present?
  end

  def unauthenticated
    user_id.nil?
  end

  def authenticated?
    user_id.present?
  end

  def mark_as_resolved!(resolved_by: nil)
    update(resolved_at: Time.current, resolved_by: resolved_by)
  end

  def display_name
    "[#{severity.upcase}] #{message.truncate(100)}"
  end

  def formatted_context
    return "" if context.blank?
    JSON.pretty_generate(context)
  rescue
    context.to_s
  end

  def has_storage_issues?
    local_storage_keys.present? || session_storage_keys.present? || cookies.present?
  end

  def storage_snapshot
    {
      local_storage: local_storage_keys || [],
      session_storage: session_storage_keys || [],
      cookies: cookies || {}
    }
  end

  # ===== RESOLUTION HELPERS =====
  def resolve!(resolved_by: nil)
    update!(resolved_at: Time.current, resolved_by: resolved_by)
  end

  def unresolve!
    update!(resolved_at: nil, resolved_by: nil)
  end
end
