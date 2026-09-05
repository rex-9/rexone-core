# app/services/data_sync_service.rb
# frozen_string_literal: true

class DataSyncService
  LOG_PREFIX = "[DataSyncService]"

  class << self
    # Sync all system data counters and metrics.
    #
    # Note: Notification sent_count and read_count are cumulative lifetime counters
    # maintained in real-time via UserNotification transactional lifecycle callbacks.
    # They are intentionally excluded from recounting to prevent retention cleanup
    # (Notification::CleanupJob) from reducing lifetime telemetry.
    def sync_all!
      Rails.logger.info("#{LOG_PREFIX} Starting full data synchronization...")
      results = {}

      # Registered sync routines for non-lossy resources can be appended here.
      results[:synced_at] = Time.current

      Rails.logger.info("#{LOG_PREFIX} Full data synchronization complete.")
      results
    end
  end
end
