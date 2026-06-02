# Tracks failed password attempts per user/device in Redis.
#
# Lock policy (progressive back-off):
#   failures 1-2  -> no cooldown yet
#   failure 3     -> 30 s cooldown  (lock_level 1)
#   failures 4-5  -> no cooldown yet
#   failure 6     -> 60 s cooldown  (lock_level 2)
#   failures 7+   -> 120 s cooldown (lock_level 3, every failure)
#
# All state mutations are performed inside Lua scripts so they are
# guaranteed atomic even under concurrent requests or cluster replication.
# On Redis errors the service FAILS OPEN (allows the attempt) to avoid a
# Redis outage becoming a self-inflicted DoS, while logging a critical alert.
class PasswordAttemptService
  KEY_PREFIX = "password:attempts".freeze
  KEY_TTL    = 24.hours.to_i   # auto-expire idle keys after 24 h

  LOCK_LEVELS = [
    { max_failures: 3,               duration: 30  }, # level 1
    { max_failures: 6,               duration: 60  }, # level 2
    { max_failures: Float::INFINITY, duration: 120 }  # level 3
  ].freeze

  # @param user_id  [String, Integer]
  # @param device_id [String, nil]  opaque token from X-Device-ID header
  # @param ip        [String, nil]  request.remote_ip (for logging only)
  def initialize(user_id:, device_id: nil, ip: nil)
    @user_id   = user_id
    @device_id = device_id.presence
    @ip        = ip
    @redis     = PASSWORD_REDIS
    @key       = build_key
  end

  # -- Public interface ------------------------------------------------------

  # Returns full state hash from Redis.
  # { locked:, cooldown_remaining:, lock_level:, failed_attempts:, last_attempt_at: }
  def status
    locked, remaining = check_lock_atomic
    raw = @redis.hgetall(@key)
    {
      locked:             locked,
      cooldown_remaining: remaining,
      lock_level:         raw["lock_level"].to_i,
      failed_attempts:    raw["failed_attempts"].to_i,
      last_attempt_at:    raw["last_attempt_at"]&.to_f
    }
  rescue Redis::BaseError => e
    handle_redis_error("status", e)
    { locked: false, cooldown_remaining: 0, lock_level: 0, failed_attempts: 0, last_attempt_at: nil }
  end

  # Fast locked? check used by the before_action guard.
  # Returns { locked: Boolean, cooldown_remaining: Integer }
  def locked?
    locked, remaining = check_lock_atomic
    { locked: locked, cooldown_remaining: remaining }
  rescue Redis::BaseError => e
    handle_redis_error("locked?", e)
    { locked: false, cooldown_remaining: 0 }   # fail open
  end

  # Atomically increments the failure counter and sets the next cooldown.
  # Returns { failed_attempts:, lock_level:, cooldown_remaining:, cooldown_until: }
  def record_failure
    failed, level, cooldown_until_s = record_failure_atomic
    cooldown_until = cooldown_until_s.to_f
    cooldown_remaining = [ (cooldown_until - Time.current.to_f).ceil, 0 ].max

    log_suspicious_activity(failed, level)

    {
      failed_attempts:    failed,
      lock_level:         level,
      cooldown_until:     cooldown_until,
      cooldown_remaining: cooldown_remaining
    }
  rescue Redis::BaseError => e
    handle_redis_error("record_failure", e)
    { failed_attempts: 1, lock_level: 1, cooldown_until: Time.current.to_f + 30, cooldown_remaining: 30 }
  end

  # Clears all attempt state after a successful password verification.
  def record_success
    @redis.del(@key)
    Rails.logger.info(
      "[Password] SUCCESS user=#{@user_id} device=#{masked_device} ip=#{@ip} - attempts cleared"
    )
  rescue Redis::BaseError => e
    handle_redis_error("record_success", e)
  end

  # -- Lua scripts (atomic) --------------------------------------------------

  # Returns [is_locked (0|1), cooldown_remaining_seconds (integer)]
  CHECK_LOCK_SCRIPT = <<~LUA.freeze
    local cooldown_until = tonumber(redis.call('HGET', KEYS[1], 'cooldown_until'))
    local now            = tonumber(ARGV[1])

    if cooldown_until ~= nil and cooldown_until > now then
      return { 1, math.ceil(cooldown_until - now) }
    else
      return { 0, 0 }
    end
  LUA

  # Increments failure counter and sets a new cooldown.
  # Returns [failed_attempts, lock_level, cooldown_until_string]
  RECORD_FAILURE_SCRIPT = <<~LUA.freeze
    local key  = KEYS[1]
    local now  = tonumber(ARGV[1])
    local ttl  = tonumber(ARGV[2])

    local failed = tonumber(redis.call('HGET', key, 'failed_attempts')) or 0
    failed = failed + 1

    local level, duration
    if failed <= 3 then
      level    = 1
      if failed == 3 then
        duration = 30
      else
        duration = 0
      end
    elseif failed <= 6 then
      level    = 2
      if failed == 6 then
        duration = 60
      else
        duration = 0
      end
    else
      level    = 3
      duration = 120
    end

    local cooldown_until = now + duration

    redis.call('HSET', key,
      'failed_attempts', tostring(failed),
      'cooldown_until',  tostring(cooldown_until),
      'lock_level',      tostring(level),
      'last_attempt_at', tostring(now)
    )
    redis.call('EXPIRE', key, ttl)

    return { failed, level, tostring(cooldown_until) }
  LUA

  private

  # -- Redis helpers ---------------------------------------------------------

  def check_lock_atomic
    result = @redis.eval(CHECK_LOCK_SCRIPT, keys: [ @key ], argv: [ Time.current.to_f.to_s ])
    [ result[0].to_i == 1, result[1].to_i ]
  end

  def record_failure_atomic
    result = @redis.eval(
      RECORD_FAILURE_SCRIPT,
      keys: [ @key ],
      argv: [ Time.current.to_f.to_s, KEY_TTL.to_s ]
    )
    [ result[0].to_i, result[1].to_i, result[2].to_s ]
  end

  # -- Helpers ---------------------------------------------------------------

  def build_key
    parts = [ KEY_PREFIX, "user:#{@user_id}" ]
    parts << "device:#{Digest::SHA256.hexdigest(@device_id)}" if @device_id
    parts.join(":")
  end

  def masked_device
    return "none" unless @device_id
    "#{@device_id[0, 8]}****"
  end

  def log_suspicious_activity(failed_attempts, lock_level)
    return unless lock_level >= 2

    Rails.logger.warn(
      "[Password] SUSPICIOUS - user=#{@user_id} device=#{masked_device} ip=#{@ip} " \
      "failed_attempts=#{failed_attempts} lock_level=#{lock_level}"
    )
  end

  def handle_redis_error(operation, error)
    Rails.logger.error(
      "[Password] CRITICAL - Redis error in #{operation}: #{error.message} " \
      "(user=#{@user_id}, failing open)"
    )
  end
end