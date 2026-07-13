# app/services/password_attempt_service.rb
class PasswordAttemptService
  def initialize(user_id)
    @key = "password:attempts:#{user_id}"
    @redis = PASSWORD_REDIS
  end

  def allowed?
    cooldown_remaining <= 0
  end

  def cooldown_remaining
    cooldown_until = @redis.get("#{@key}:cooldown_until").to_i
    remaining = cooldown_until - Time.now.to_i
    remaining > 0 ? remaining : 0
  end

  def record_failure
    attempts = @redis.incr(@key)
    @redis.expire(@key, 3600) # 1 hour window

    # Cooldown levels: 3, 6, 9 attempts
    cooldown = case attempts
               when 3   then 30
               when 6   then 60
               when 9   then 120
               else 0
               end

    if cooldown > 0
      @redis.set("#{@key}:cooldown_until", Time.now.to_i + cooldown)
      @redis.expire("#{@key}:cooldown_until", cooldown + 5)
      @redis.del(@key) # Reset attempts after cooldown
    end

    {
      remaining_attempts: cooldown > 0 ? 0 : 3 - (attempts % 3),
      cooldown_remaining: cooldown,
      cooldown_active: cooldown > 0
    }
  end

  def record_success
    @redis.del(@key, "#{@key}:cooldown_until")
  end
end