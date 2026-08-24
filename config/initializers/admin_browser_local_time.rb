# frozen_string_literal: true

# Pulse, Solid Web UI, and RED render timestamps in UTC (app time zone / gem
# defaults / Docker). Administrate already emits <time datetime="ISO"> and
# converts in the browser. Wrap the other dashboards the same way.

module AdminBrowserLocalTime
  SCRIPT_PATH = Rails.root.join("app/assets/javascripts/admin_datetime.js")

  def self.javascript
    SCRIPT_PATH.read
  end

  def self.script_tag(view, nonce: nil)
    attributes = {}
    attributes[:nonce] = nonce if nonce.present?
    view.content_tag(:script, javascript.html_safe, attributes)
  end

  module TimeTag
    private

    def admin_local_time_tag(time)
      utc = time.respond_to?(:utc) ? time.utc : time
      iso = utc.iso8601
      content_tag(:time, iso, class: "admin-local-time", datetime: iso, title: "#{iso} (UTC)")
    end
  end

  module SolidShortTime
    include TimeTag

    def short_time(time)
      return "—" if time.nil?

      admin_local_time_tag(time)
    end
  end

  module PulseFormatting
    include TimeTag

    def human_readable_occurred_at(occurred_at)
      return "" unless occurred_at.present?

      time = occurred_at.is_a?(String) ? Time.parse(occurred_at) : occurred_at
      admin_local_time_tag(time)
    end

    def human_readable_summary_period(summary)
      return "" unless summary&.period_start&.present? && summary&.period_end&.present?

      case summary.period_type
      when "hour"
        safe_join([ admin_local_time_tag(summary.period_start), " - ", admin_local_time_tag(summary.period_end) ])
      when "day"
        admin_local_time_tag(summary.period_start)
      end
    end
  end

  module PulseController
    extend ActiveSupport::Concern

    included do
      before_action :inject_admin_browser_local_time_script
    end

    private

    def inject_admin_browser_local_time_script
      nonce = respond_to?(:rails_pulse_csp_nonce, true) ? rails_pulse_csp_nonce : nil
      content_for :head, AdminBrowserLocalTime.script_tag(view_context, nonce: nonce)
    end
  end

  module RedController
    extend ActiveSupport::Concern

    included do
      after_action :inject_admin_browser_local_time_script
    end

    private

    def inject_admin_browser_local_time_script
      return unless response.media_type&.include?("html")

      body = response.body
      return unless body.is_a?(String) && body.include?("</body>")

      nonce = view_context.try(:red_csp_nonce)
      response.body = body.sub("</body>", "#{AdminBrowserLocalTime.script_tag(view_context, nonce: nonce)}</body>")
    end
  end
end

Rails.application.config.to_prepare do
  if defined?(SolidWebUi::Queue::ApplicationHelper)
    SolidWebUi::Queue::ApplicationHelper.prepend(AdminBrowserLocalTime::SolidShortTime)
  end
  if defined?(SolidWebUi::Cache::ApplicationHelper)
    SolidWebUi::Cache::ApplicationHelper.prepend(AdminBrowserLocalTime::SolidShortTime)
  end
  if defined?(SolidWebUi::Cable::ApplicationHelper)
    SolidWebUi::Cable::ApplicationHelper.prepend(AdminBrowserLocalTime::SolidShortTime)
  end

  if defined?(RailsPulse::FormattingHelper)
    RailsPulse::FormattingHelper.prepend(AdminBrowserLocalTime::PulseFormatting)
  end

  if defined?(RailsPulse::ApplicationController)
    RailsPulse::ApplicationController.include(AdminBrowserLocalTime::PulseController)
  end

  if defined?(RailsErrorDashboard::ApplicationController)
    RailsErrorDashboard::ApplicationController.include(AdminBrowserLocalTime::RedController)
  end
end
