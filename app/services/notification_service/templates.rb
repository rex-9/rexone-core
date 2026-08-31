# app/services/notification_service/templates.rb
module NotificationService
  module Templates
    GENERAL_ANNOUNCEMENT = "general_announcement"
    MAINTENANCE_NOTICE = "maintenance_notice"
    FEATURE_UPDATE = "feature_update"

    class << self
      def events
        [
          GENERAL_ANNOUNCEMENT,
          MAINTENANCE_NOTICE,
          FEATURE_UPDATE
        ]
      end

      def catalog
        events.map do |event|
          {
            event: event,
            label: event.humanize,
            category: "broadcast",
            admin_available: true
          }
        end
      end

      def admin_available?(event)
        events.include?(event)
      end

      def render(event)
        raise ArgumentError, "Unknown notification event: #{event}" unless admin_available?(event)

        title = I18n.t("notification.templates.#{event}.title")
        message = I18n.t("notification.templates.#{event}.body")

        {
          event: event,
          title: title,
          message: message,
          email_template: event
        }
      end
    end
  end
end
