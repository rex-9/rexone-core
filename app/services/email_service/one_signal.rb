# app/services/email_service/one_signal.rb
require "rest-client"

module EmailService
  class OneSignal < Base
    LOG_PREFIX = "[OneSignal]".freeze

    def initialize
      @app_id = AppConfig::ONE_SIGNAL_APP_ID
      @api_key = AppConfig::ONE_SIGNAL_API_KEY

      if @app_id.blank? || @api_key.blank?
        Rails.logger.info("#{LOG_PREFIX} not configured - email delivery disabled")
        @disabled = true
      end
    end

    def send_email(to:, subject:, body:, from: nil, reply_to: nil, **kwargs)
      return { "disabled" => true } if @disabled

      rendered_body = if body.to_s.strip.start_with?("<!doctype", "<html", "<table")
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
        app_id: @app_id,
        target_channel: "email",
        email_subject: subject,
        email_body: rendered_body,
        email_from: from || AppConfig::FROM_EMAIL,
        email_to: [ to ]
      }

      response = RestClient.post(
        "https://api.onesignal.com/notifications",
        payload.to_json,
        {
          content_type: :json,
          accept: :json,
          Authorization: "Key #{@api_key}"
        }
      )
      JSON.parse(response.body)
    rescue RestClient::Exception => e
      Rails.logger.error("#{LOG_PREFIX} Email failed: #{e.response&.body}")
      raise EmailService::Error, "Failed to send email: #{e.message}"
    end

    # Send using local TemplateRenderer or OneSignal Dashboard template
    def send_template(to:, template_id:, template_data: {}, from: nil)
      return { "disabled" => true } if @disabled

      # 1. Prefer local TemplateRenderer
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

      # 2. Fallback to OneSignal Dashboard template if local template doesn't exist
      template = fetch_template(template_id)
      body = render_template(template, template_data)
      subject = template_data[:subject] ||
                template&.dig("subject") ||
                fallback_subject(template_id, template_data)

      send_email(
        to: to,
        subject: subject,
        body: body,
        from: from
      )
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Template email failed: #{e.message}")
      false
    end

    private

    def fallback_subject(template_id, data)
      TemplateRenderer.subject(template_id, data).presence ||
        template_id.to_s.tr("_", " ").titleize.presence ||
        MessageService::Notification.t(MessageService::Notification::DEFAULT_TITLE)
    end

    def fetch_template(template_id)
      # In production, you could cache this
      @templates ||= {}
      return @templates[template_id] if @templates[template_id]

      response = RestClient.get(
        "https://api.onesignal.com/apps/#{@app_id}/email_templates/#{template_id}",
        { Authorization: "Key #{@api_key}" }
      )
      @templates[template_id] = JSON.parse(response.body)
    rescue RestClient::Exception => e
      Rails.logger.error("#{LOG_PREFIX} Failed to fetch template: #{e.message}")
      nil
    end

    def render_template(template, data)
      if template.nil?
        return MessageService::Notification.t(
          MessageService::Notification::TEMPLATE_NOT_FOUND
        )
      end

      html = template["html"] || template["body"]

      # Simple variable replacement
      data.each do |key, value|
        html.gsub!("{{#{key}}}", value.to_s)
      end

      html
    end
  end

  class Error < StandardError; end
end
