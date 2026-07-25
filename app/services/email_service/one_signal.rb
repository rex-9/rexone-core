# app/services/email_service/one_signal.rb
require "rest-client"

module EmailService
  class OneSignal < Base
    def initialize
      @app_id = AppConfig::ONE_SIGNAL_APP_ID
      @api_key = AppConfig::ONE_SIGNAL_API_KEY
    end

    def send_email(to:, subject:, body:, from: nil, reply_to: nil)
      payload = {
        app_id: @app_id,
        email_subject: subject,
        email_body: body,
        email_from: from || AppConfig::FROM_EMAIL,
        include_email_tokens: [ to ]
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
      Rails.logger.error("[OneSignal] Email failed: #{e.response&.body}")
      raise EmailService::Error, "Failed to send email: #{e.message}"
    end

    # Send using a template created in OneSignal Dashboard
    def send_template(to:, template_id:, template_data:, from: nil)
      # Fetch template from OneSignal (or use cached version)
      template = fetch_template(template_id)

      # Replace template variables with data
      body = render_template(template, template_data)
      subject = template_data[:subject] || template["subject"] || "Notification"

      send_email(
        to: to,
        subject: subject,
        body: body,
        from: from
      )
    rescue => e
      Rails.logger.error("[OneSignal] Template email failed: #{e.message}")
      false
    end

    private

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
      Rails.logger.error("[OneSignal] Failed to fetch template: #{e.message}")
      nil
    end

    def render_template(template, data)
      return "Template not found" if template.nil?

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
