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

      # Reconcile coupon used_count against user_coupons ledger
      reconciled_coupons = 0
      Payment::Coupon.with_discarded.find_each do |coupon|
        actual_count = coupon.user_coupons.count
        if coupon.used_count != actual_count
          coupon.update_columns(used_count: actual_count)
          reconciled_coupons += 1
        end
      end
      results[:reconciled_coupons] = reconciled_coupons

      results[:synced_at] = Time.current

      Rails.logger.info("#{LOG_PREFIX} Full data synchronization complete. Reconciled #{reconciled_coupons} coupons.")
      results
    end
  end
end
