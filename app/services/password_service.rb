# app/services/password_service.rb
class PasswordService
  def initialize(user_id)
    @user_id = user_id
    @attempts_key = "password:attempts:#{user_id}"
    @cooldown_key = "password:cooldown:#{user_id}"
  end

  def allowed?
    cooldown_remaining <= 0
  end

  def cooldown_remaining
    cooldown_until = CacheService.read(@cooldown_key).to_i
    remaining = cooldown_until - Time.now.to_i
    remaining > 0 ? remaining : 0
  end

  def record_failure
    # Increment attempts with 1-hour window
    attempts = CacheService.increment(@attempts_key, 1, expires_in: 1.hour) || 1

    # Calculate cooldown based on attempts (3, 6, 9, 12+)
    cooldown = case attempts
    when 1, 2   then 0   # No cooldown, but count continues
    when 3      then 30
    when 4, 5   then 0   # No cooldown, but count continues
    when 6      then 60
    when 7, 8   then 0   # No cooldown, but count continues
    when 9      then 120
    when 10, 11 then 0   # No cooldown, but count continues
    else             300 # Max 5 minutes for 12+
    end

    if cooldown > 0
      cooldown_until = Time.now.to_i + cooldown
      CacheService.write(@cooldown_key, cooldown_until, expires_in: cooldown + 5)
    end

    {
      remaining_attempts: cooldown > 0 ? 0 : 3 - (attempts % 3),
      cooldown_remaining: cooldown,
      locked: cooldown > 0
    }
  end

  def record_success
    CacheService.delete(@attempts_key)
    CacheService.delete(@cooldown_key)
  rescue => e
    Rails.logger.error("[PasswordService] Failed to record success: #{e.message}")
  end
end
