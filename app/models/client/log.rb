# app/models/client/log_client.rb
class Client::Log < ApplicationRecord
  self.table_name = "client_logs"

  # ===== ENUMS =====
  enum :severity, {
    debug: LogConstants::Severity::DEBUG,
    info: LogConstants::Severity::INFO,
    warning: LogConstants::Severity::WARNING,
    error: LogConstants::Severity::ERROR,
    critical: LogConstants::Severity::CRITICAL
  }, prefix: :client_severity

  enum :platform, {
    web: LogConstants::Platform::WEB,
    ios: LogConstants::Platform::IOS,
    android: LogConstants::Platform::ANDROID
  }, prefix: :client_platform

  enum :environment, {
    development: LogConstants::Environment::DEVELOPMENT,
    staging: LogConstants::Environment::STAGING,
    production: LogConstants::Environment::PRODUCTION
  }, prefix: :client_environment

  # ===== ASSOCIATIONS =====
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true
  belongs_to :version, class_name: "Client::Version", optional: true

  has_metadata Client::Log::Metadata

  # ===== VALIDATIONS =====
  validates :message, presence: true
  validates :severity, presence: true
  validate :validate_json

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
  scope :with_storage_issues, -> { where("cardinality(local_storage_keys) > 0 OR cardinality(session_storage_keys) > 0") }

  # ===== INSTANCE METHODS =====
  def resolved?
    resolved_at.present?
  end

  def unauthenticated?
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

  def formatted_metadata
    return "" if metadata.blank?
    JSON.pretty_generate(metadata)
  rescue
    metadata.to_s
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

  private

  def validate_json
    if cookies.present?
      if !cookies.is_a?(Hash)
        errors.add(:cookies, "must be a valid key-value object")
      elsif !cookies.values.all? { |v| v.is_a?(String) || v.is_a?(Numeric) || v.nil? }
        errors.add(:cookies, "must contain only scalar string or numeric values")
      end
    end
    errors.add(:stack_trace, "must be a valid array") if stack_trace.present? && !stack_trace.is_a?(Array)
    errors.add(:local_storage_keys, "must be a valid array") if local_storage_keys.present? && !local_storage_keys.is_a?(Array)
    errors.add(:session_storage_keys, "must be a valid array") if session_storage_keys.present? && !session_storage_keys.is_a?(Array)
  end
end
