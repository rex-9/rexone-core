require "rest-client"
require "erb"

module EmailService
  class Brevo < Base
    LOG_PREFIX = "[Brevo]".freeze
    SEND_EMAIL_ENDPOINT = "/smtp/email".freeze

    def initialize
      @api_key = AppConfig::BREVO_API_KEY
      @base_url = AppConfig::BREVO_BASE_URL

      if @api_key.blank?
        Rails.logger.info("#{LOG_PREFIX} not configured - email delivery disabled")
        @disabled = true
      end
    end

    def send_email(to:, subject:, body:, from: nil, reply_to: nil)
      return { "disabled" => true } if @disabled

      payload = {
        sender: sender_payload(from),
        to: recipients_payload(to),
        subject: subject,
        htmlContent: body
      }
      payload[:replyTo] = address_payload(reply_to) if reply_to.present?

      post(payload)
    end

    def send_template(to:, template_id:, template_data: {}, from: nil)
      return { "disabled" => true } if @disabled

      if brevo_template_id?(template_id)
        return post(
          sender: sender_payload(from),
          to: recipients_payload(to),
          templateId: template_id.to_i,
          params: template_data
        )
      end

      Rails.logger.warn("#{LOG_PREFIX} template_id=#{template_id.inspect} is not a Brevo numeric template ID; falling back to plain HTML email")
      send_email(
        to: to,
        subject: fallback_subject(template_id, template_data),
        body: fallback_body(template_id, template_data),
        from: from
      )
    end

    private

    def post(payload)
      response = RestClient.post(
        "#{@base_url}#{SEND_EMAIL_ENDPOINT}",
        payload.compact.to_json,
        {
          content_type: :json,
          accept: :json,
          "api-key": @api_key
        }
      )
      JSON.parse(response.body)
    rescue RestClient::Exception => e
      Rails.logger.error("#{LOG_PREFIX} Email failed: #{e.response&.body || e.message}")
      raise EmailService::Error, "Failed to send email: #{e.message}"
    end

    def sender_payload(from)
      address_payload(from.presence || AppConfig::FROM_EMAIL)
    end

    def recipients_payload(to)
      Array(to).filter_map do |recipient|
        address_payload(recipient) if recipient.present?
      end
    end

    def address_payload(value)
      return value if value.is_a?(Hash)

      { email: value.to_s }
    end

    def brevo_template_id?(template_id)
      template_id.to_s.match?(/\A\d+\z/)
    end

    def fallback_subject(template_id, data)
      TemplateRenderer.subject(template_id, data).presence ||
        template_id.to_s.tr("_", " ").titleize.presence ||
        MessageService::Notification.t(MessageService::Notification::DEFAULT_TITLE)
    end

    def fallback_body(template_id, data)
      rendered_template = TemplateRenderer.render(template_id, data)
      return rendered_template if rendered_template.present?

      rows = data.map do |key, value|
        "<p><strong>#{ERB::Util.html_escape(key.to_s.humanize)}:</strong> #{ERB::Util.html_escape(value.to_s)}</p>"
      end.join

      rows.presence ||
        "<p>#{ERB::Util.html_escape(fallback_subject(template_id, data))}</p>"
    end
  end
end
