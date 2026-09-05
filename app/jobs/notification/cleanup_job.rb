# app/jobs/notification/cleanup_job.rb
class Notification::CleanupJob < ApplicationJob
  queue_as :default

  def perform
    read_cutoff = AppConfig::NOTIFICATION_READ_RETENTION_DAYS.days.ago
    unread_cutoff = AppConfig::NOTIFICATION_UNREAD_RETENTION_DAYS.days.ago
    discarded_cutoff = AppConfig::NOTIFICATION_DISCARDED_RETENTION_DAYS.days.ago

    # 1. Purge soft-deleted / discarded notifications older than 7 days
    discarded_count = UserNotification.unscoped
                                      .where.not(discarded_at: nil)
                                      .where("discarded_at < ?", discarded_cutoff)
                                      .delete_all

    # 2. Purge read notifications older than 30 days
    read_count = UserNotification.where.not(read_at: nil)
                                 .where("read_at < ?", read_cutoff)
                                 .delete_all

    # 3. Purge unread notifications older than 90 days
    unread_count = UserNotification.where(read_at: nil)
                                   .where("created_at < ?", unread_cutoff)
                                   .delete_all

    Rails.logger.info(
      "[Notification::CleanupJob] Purged #{discarded_count} discarded, " \
      "#{read_count} read, and #{unread_count} unread notifications."
    )

    {
      discarded: discarded_count,
      read: read_count,
      unread: unread_count
    }
  end
end
