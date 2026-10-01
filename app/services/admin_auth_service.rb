# app/services/admin_auth_service.rb
class AdminAuthService
  REALM = "Admin Area".freeze
  LOG_PREFIX = "[AdminAuth]".freeze

  IP_MAX_FAILED_ATTEMPTS = 5
  IP_ATTEMPT_WINDOW = 15.minutes
  IP_LOCKOUT_DURATION = 15.minutes

  class << self
    # Authenticates an administrator using strictly their username and passcode/password.
    # Enforces PasswordService attempt limiting/cooldowns on the user, and IP-level lockouts
    # to protect against automated passcode generators and brute-force attacks.
    def authenticate(username:, password:, ip: nil)
      return nil if username.blank? || password.blank?

      clean_username = username.to_s.strip.downcase

      # Check if this IP is currently locked out from admin attempts
      if ip.present? && ip_locked_out?(ip)
        Rails.logger.warn("#{LOG_PREFIX} Request from locked-out IP #{ip} rejected")
        return nil
      end

      # STRICT RULE: Always username, NEVER email
      user = User.find_by("LOWER(username) = ?", clean_username)

      # If user not found or not an admin, treat as failed attempt at IP level
      unless user&.admin?
        record_ip_failure(ip) if ip.present?
        Rails.logger.warn("#{LOG_PREFIX} Invalid admin username attempt: #{clean_username} from IP #{ip}")
        return nil
      end

      # User-level passcode protection via PasswordService
      limiter = PasswordService.new(user.id)
      unless limiter.allowed?
        Rails.logger.warn(
          "#{LOG_PREFIX} Admin #{clean_username} is in cooldown for #{limiter.cooldown_remaining}s"
        )
        return nil
      end

      if user.valid_password?(password)
        limiter.record_success
        clear_ip_failure(ip) if ip.present?
        user
      else
        limiter.record_failure
        record_ip_failure(ip) if ip.present?
        Rails.logger.warn("#{LOG_PREFIX} Failed passcode for admin #{clean_username} from IP #{ip}")
        nil
      end
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Authentication error: #{e.message}")
      nil
    end

    # Shared HTTP Basic Auth execution for ActionController instances
    def http_basic_authenticate(controller)
      controller.authenticate_or_request_with_http_basic(REALM) do |username, password|
        client_ip = controller.request.remote_ip rescue nil
        user = authenticate(username: username, password: password, ip: client_ip)

        if user
          controller.instance_variable_set(:@current_user, user) if controller.respond_to?(:instance_variable_set)
          Current.auditor = user
          true
        else
          false
        end
      end
    end

    private

    def ip_attempts_key(ip)
      "admin:ip_attempts:#{ip}"
    end

    def ip_lockout_key(ip)
      "admin:ip_lockout:#{ip}"
    end

    def ip_locked_out?(ip)
      CacheService.exist?(ip_lockout_key(ip))
    end

    def record_ip_failure(ip)
      attempts = CacheService.increment(ip_attempts_key(ip), 1, expires_in: IP_ATTEMPT_WINDOW) || 1

      if attempts >= IP_MAX_FAILED_ATTEMPTS
        CacheService.write(ip_lockout_key(ip), true, expires_in: IP_LOCKOUT_DURATION)
        Rails.logger.warn(
          "#{LOG_PREFIX} IP #{ip} reached #{attempts} failed admin attempts. Locked out for #{IP_LOCKOUT_DURATION / 60} minutes."
        )
      end
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Failed to record IP failure: #{e.message}")
    end

    def clear_ip_failure(ip)
      CacheService.delete(ip_attempts_key(ip))
      CacheService.delete(ip_lockout_key(ip))
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Failed to clear IP failure: #{e.message}")
    end
  end
end
