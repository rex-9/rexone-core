module EmailService
  class TemplateRenderer
    TEMPLATE_ROOT = Rails.root.join("docs/email_templates").freeze

    SUBJECTS = {
      "email_confirmation" => "Confirm your Rexone email",
      "password_reset" => "Reset your Rexone passcode",
      "payment_purchase_confirmation" => "Payment confirmation",
      "payment_failed" => "Payment failed - action required",
      "payment_subscription_confirmation" => "Subscription confirmation",
      "payment_subscription_canceled" => "Subscription canceled",
      "payment_subscription_resumed" => "Subscription resumed",
      "welcome" => "Welcome to Rexone",
      "sign_in_alert" => "Security alert: new sign-in"
    }.freeze

    class << self
      def render(template_id, data = {})
        template_path = path_for(template_id)
        return unless template_path.file?

        replace_placeholders(template_path.read, data)
      end

      def subject(template_id, data = {})
        replace_placeholders(data[:subject].presence || data["subject"].presence || SUBJECTS[template_id.to_s], data)
      end

      private

      def path_for(template_id)
        TEMPLATE_ROOT.join("#{template_id}.html")
      end

      def replace_placeholders(content, data)
        content.to_s.gsub(/\{\{([a-zA-Z0-9_]+)\}\}/) do
          ERB::Util.html_escape(data[$1.to_sym] || data[$1] || "")
        end
      end
    end
  end
end
