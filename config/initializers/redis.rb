# config/initializers/redis.rb

# Dedicated Redis client for password attempt tracking.
# Isolated from Action Cable's Redis connection to prevent cross-contamination
# of failure state data with pub/sub traffic.
#
# Uses DB index 1 to keep password keys separate from the default DB 0.
PASSWORD_REDIS = Redis.new(
  url: ENV.fetch("RAILS_REDIS_URL", "redis://localhost:6379/0").sub(%r{/\d+$}, "/1"),
  timeout: 2,
  reconnect_attempts: 2
)

# Test connection on startup
begin
  PASSWORD_REDIS.ping
rescue Redis::BaseError => e
  Rails.logger.error("[Redis] Password Redis connection failed: #{e.message}")
end