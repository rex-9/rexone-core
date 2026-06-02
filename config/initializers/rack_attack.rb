# IP-level rate limiting using Rack::Attack.
# This is a first-line defence against request flooding and scripted attacks.
# It operates at the Rack layer — before any Rails controller code runs —
# so it cannot be bypassed by application-level changes.
#
# Architecture note:
#   Rack::Attack  → protects the HTTP layer  (IP / endpoint throttling)
#   PasswordAttemptService → protects the business layer (user / device locks)
#
# Both layers must be satisfied for a request to proceed.
Rails.application.config.middleware.use Rack::Attack

Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url:       ENV.fetch("RAILS_REDIS_URL", "redis://localhost:6379/0"),
  namespace: "rack_attack",
  expires_in: 10.minutes
)

class Rack::Attack
  # ── Throttles ────────────────────────────────────────────────────────────────

  # Allow up to 60 requests/min per IP to any password endpoint.
  # Catches general flooding before it reaches the application.
  throttle("password/req/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/password")
  end

  # Strict limit: 10 POST attempts per IP per 5 minutes.
  # Prevents an attacker from cycling through users from a single IP.
  throttle("password/verify/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path == "/password/verify" && req.post?
  end

  # Per-user throttle derived from a stable token in the request body/header.
  # Complements the PasswordAttemptService lock (which is also per-user) but
  # operates without needing a DB/Redis lookup for the User record.
  throttle("password/verify/user_token", limit: 15, period: 5.minutes) do |req|
    if req.path == "/password/verify" && req.post?
      # Use X-Device-ID if present; fall back to IP so the throttle always fires.
      req.get_header("HTTP_X_DEVICE_ID").presence || req.ip
    end
  end

  # ── Blocked response ─────────────────────────────────────────────────────────

  self.throttled_responder = lambda do |env|
    match_data  = env["rack.attack.match_data"] || {}
    period      = match_data[:period] || 60
    retry_after = (period - (Time.now.to_i % period)).to_s

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After"  => retry_after
      },
      [ {
          success:     false,
          message:     "Too many requests. Please slow down.",
          retry_after: retry_after.to_i
        }.to_json ]
    ]
  end

  self.blocklisted_responder = lambda do |_env|
    [
      403,
      { "Content-Type" => "application/json" },
      [ { success: false, message: "Request blocked." }.to_json ]
    ]
  end
end
