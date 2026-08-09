# app/services/cache_service.rb
class CacheService
  # Base key for all cache entries
  PREFIX = "app".freeze

  class << self
    # Write to cache with expiration
    def write(key, value, expires_in: nil)
      full_key = full_key(key)
      if expires_in
        Rails.cache.write(full_key, value, expires_in: expires_in)
      else
        Rails.cache.write(full_key, value)
      end
    rescue => e
      Rails.logger.error("[Cache] Write failed for #{full_key}: #{e.message}")
      nil
    end

    # Read from cache
    def read(key)
      full_key = full_key(key)
      Rails.cache.read(full_key)
    rescue => e
      Rails.logger.error("[Cache] Read failed for #{full_key}: #{e.message}")
      nil
    end

    # Delete from cache
    def delete(key)
      full_key = full_key(key)
      Rails.cache.delete(full_key)
    rescue => e
      Rails.logger.error("[Cache] Delete failed for #{full_key}: #{e.message}")
      nil
    end

    # Atomic increment (Solid Cache supports this via Rails.cache.increment)
    def increment(key, amount = 1, expires_in: nil)
      full_key = full_key(key)
      if expires_in
        Rails.cache.increment(full_key, amount, expires_in: expires_in)
      else
        Rails.cache.increment(full_key, amount)
      end
    rescue => e
      Rails.logger.error("[Cache] Increment failed for #{full_key}: #{e.message}")
      nil
    end

    # Atomic decrement
    def decrement(key, amount = 1)
      full_key = full_key(key)
      Rails.cache.decrement(full_key, amount)
    rescue => e
      Rails.logger.error("[Cache] Decrement failed for #{full_key}: #{e.message}")
      nil
    end

    # Get or set with block
    def fetch(key, expires_in: nil, &block)
      full_key = full_key(key)
      Rails.cache.fetch(full_key, expires_in: expires_in, &block)
    rescue => e
      Rails.logger.error("[Cache] Fetch failed for #{full_key}: #{e.message}")
      yield if block_given?
    end

    # Check if key exists
    def exist?(key)
      full_key = full_key(key)
      Rails.cache.exist?(full_key)
    rescue => e
      Rails.logger.error("[Cache] Exist check failed for #{full_key}: #{e.message}")
      false
    end

    # Get all keys matching pattern (limited)
    def keys(pattern)
      # Solid Cache doesn't support pattern matching directly,
      # so we'll use the Rails cache store's keys method if available
      if Rails.cache.respond_to?(:keys)
        Rails.cache.keys(full_key(pattern))
      else
        Rails.logger.warn("[Cache] Keys pattern matching not supported by current cache store")
        []
      end
    rescue => e
      Rails.logger.error("[Cache] Keys pattern failed: #{e.message}")
      []
    end

    private

    def full_key(key)
      "#{PREFIX}:#{key}"
    end
  end
end
