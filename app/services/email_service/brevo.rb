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

    def send_email(to:, subject:, body:, from: nil, reply_to: nil, **kwargs)
      return { "disabled" => true } if @disabled

      rendered_body = if body.to_s.strip.start_with?("<")
        body
      else
        data = (kwargs[:data] || kwargs).with_indifferent_access
        TemplateRenderer.render_content(
          title: subject,
          body: body,
          cta_url: data[:cta_url] || data[:link] || kwargs[:link],
          cta_text: data[:cta_text],
          highlight: data[:highlight] || data[:code] || data[:promo_code],
          details: data[:details],
          disclaimer: data[:disclaimer],
          data: data
        )
      end

      payload = {
        sender: sender_payload(from),
        to: recipients_payload(to),
        subject: subject,
        htmlContent: rendered_body
      }
      payload[:replyTo] = address_payload(reply_to) if reply_to.present?

      post(payload)
    end

    def send_template(to:, template_id:, template_data: {}, from: nil)
      return { "disabled" => true } if @disabled

      # 1. Prefer local TemplateRenderer if template exists in catalog
      rendered_body = TemplateRenderer.render(template_id, template_data)
      if rendered_body.present?
        subject = TemplateRenderer.subject(template_id, template_data).presence ||
                  template_data[:subject] ||
                  fallback_subject(template_id, template_data)
        return send_email(
          to: to,
          subject: subject,
          body: rendered_body,
          from: from
        )
      end

      # 2. Brevo native numeric template ID
      if brevo_template_id?(template_id)
        return post(
          sender: sender_payload(from),
          to: recipients_payload(to),
          templateId: template_id.to_i,
          params: template_data
        )
      end

      # 3. Ad-hoc fallback
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

      body_content = data[:body].presence || data[:message].presence
      if body_content.present?
        return TemplateRenderer.render_content(
          title: fallback_subject(template_id, data),
          body: body_content,
          data: data
        )
      end

      rows = data.map do |key, value|
        "<p><strong>#{ERB::Util.html_escape(key.to_s.humanize)}:</strong> #{ERB::Util.html_escape(value.to_s)}</p>"
      end.join

      rows.presence ||
        "<p>#{ERB::Util.html_escape(fallback_subject(template_id, data))}</p>"
    end
  end
end
