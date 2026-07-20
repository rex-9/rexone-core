# app/services/email_service/one_signal.rb
require "rest-client"

module EmailService
  class OneSignal < Base
    def initialize
      @app_id = ENV.fetch("ONE_SIGNAL_APP_ID")
      @api_key = ENV.fetch("ONE_SIGNAL_API_KEY")
    end

    def send_email(to:, subject:, body:, from: nil, reply_to: nil)
      payload = {
        app_id: @app_id,
        email_subject: subject,
        email_body: body,
        email_from: from || ENV.fetch("DEFAULT_FROM_EMAIL"),
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

    def send_template(to:, template_id:, template_data:, from: nil)
      # OneSignal doesn't support templates directly
      # You'd need to build the body from template data
      # This is a placeholder - implement based on your needs
      body = template_data[:body] || "Template: #{template_id}"
      subject = template_data[:subject] || "Notification"
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
  end

  class Error < StandardError; end
end
