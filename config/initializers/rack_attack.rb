# config/initializers/rack_attack.rb
require "active_support/core_ext/numeric/time"

# Rack::Attack protects the HTTP layer before Rails controllers run.
#
# Rack::Attack    → IP / endpoint rate limiting
# PasswordService → per-user password-attempt protection
# JWT             → token authentication / expiration
# Active session  → platform-specific session enforcement

Rails.application.config.middleware.use Rack::Attack

# Disable throttling in development and test so local development and E2E suites can run freely
Rack::Attack.enabled = false if Rails.env.development? || Rails.env.test?

# Use Rails' configured cache backend (Solid Cache).
Rack::Attack.cache.store = Rails.cache

class Rack::Attack
  # ── Authentication throttles ──────────────────────────────────────────────

  # Strict limit for account peek / user existence checking (GET /peek).
  # 12 requests per minute (1 per 5 seconds) per IP to prevent email/account enumeration.
  throttle("auth/peek/ip", limit: 12, period: 1.minute) do |req|
    req.ip if req.path == "/peek" && req.get?
  end

  # Strict limit: 10 signin POST attempts per IP per 3 minutes.
  # Prevents credential stuffing attacks across any signin endpoint.
  throttle("auth/signin/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.path.start_with?("/signin") && req.post?
  end

  # Strict limit: 10 registration attempts per IP per 3 minutes.
  # Prevents bot account creation storms.
  throttle("auth/signup/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.path == "/signup" && req.post?
  end

  # Strict limit: 10 code-dispatch / password-reset requests per IP per 3 minutes.
  # Prevents transactional email bombing (confirmation codes, password resets).
  throttle("auth/codes/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.post? && (
      req.path == "/confirmation/send_code" ||
      req.path == "/password/forgot"
    )
  end

  # General baseline protection for all authentication-related endpoints.
  # Allow up to 60 requests/min per IP.
  throttle("auth/req/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?(
      "/signin",
      "/signup",
      "/confirmation",
      "/password"
    )
  end

  # ── Responses ─────────────────────────────────────────────────────────────

  self.throttled_responder = lambda do |req|
    env = req.respond_to?(:env) ? req.env : req
    match_data = env["rack.attack.match_data"] || {}
    period = match_data[:period] || 60
    retry_after = period - (Time.now.to_i % period)

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [
        {
          status: {
            code: 429,
            success: false,
            message: MessageService::Common.t(
              MessageService::Common::TOO_MANY_REQUESTS
            ),
            error: MessageService::Common.t(
              MessageService::Common::RATE_LIMIT_EXCEEDED
            )
          },
          retry_after: retry_after
        }.to_json
      ]
    ]
  end

  self.blocklisted_responder = lambda do |_env|
    [
      403,
      { "Content-Type" => "application/json" },
      [
        {
          status: {
            code: 403,
            success: false,
            message: MessageService::Common.t(
              MessageService::Common::REQUEST_BLOCKED
            )
          }
        }.to_json
      ]
    ]
  end
end
