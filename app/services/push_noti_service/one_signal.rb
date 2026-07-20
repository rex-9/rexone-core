# app/services/push_noti_service/one_signal.rb
require "rest-client"

module PushNotiService
  class OneSignal < Base
    def initialize
      @app_id = ENV.fetch("ONE_SIGNAL_APP_ID")
      @api_key = ENV.fetch("ONE_SIGNAL_API_KEY")
      @default_sound = ENV.fetch("ONE_SIGNAL_DEFAULT_SOUND", "default")

      if @app_id.blank? || @api_key.blank?
        Rails.logger.info("[OneSignal] not configured - push notifications disabled")
        @disabled = true
      end
    end

    # Send to a specific device subscription
    def send_to_device(subscription_id:, title:, body:, data: {}, sound: nil)
      payload = {
        app_id: @app_id,
        include_subscription_ids: [ subscription_id ],
        headings: { en: title },
        contents: { en: body },
        data: data,
        android_sound: sound || @default_sound,
        ios_sound: sound || @default_sound,
        target_channel: "push"
      }

      send_notification(payload)
    rescue => e
      handle_error(e, "send_to_device", subscription_id: subscription_id)
      false
    end

    # Send to all devices belonging to a user (external_id)
    def send_to_user(user_id:, title:, body:, data: {}, sound: nil)
      payload = {
        app_id: @app_id,
        include_aliases: {
          external_id: [ user_id ]
        },
        target_channel: "push",
        headings: { en: title },
        contents: { en: body },
        data: data,
        android_sound: sound || @default_sound,
        ios_sound: sound || @default_sound
      }

      send_notification(payload)
    rescue => e
      handle_error(e, "send_to_user", user_id: user_id)
      false
    end

    # Broadcast to a segment
    def send_to_segment(segment:, title:, body:, data: {}, sound: nil)
      payload = {
        app_id: @app_id,
        included_segments: [ segment ],
        target_channel: "push",
        headings: { en: title },
        contents: { en: body },
        data: data,
        android_sound: sound || @default_sound,
        ios_sound: sound || @default_sound
      }

      send_notification(payload)
    rescue => e
      handle_error(e, "send_to_segment", segment: segment)
      false
    end

    # ===== Notification Templates =====

    def welcome(user_id:, name:)
      send_to_user(
        user_id: user_id,
        title: Messages::PUSH_WELCOME_TITLE,
        body: Messages::PUSH_WELCOME_BODY.call(name: name),
        data: { type: "welcome" }
      )
    end

    def sign_in_alert(user_id:, name:)
      send_to_user(
        user_id: user_id,
        title: Messages::PUSH_SIGN_IN_ALERT_TITLE,
        body: Messages::PUSH_SIGN_IN_ALERT_BODY.call(name: name),
        data: { type: "sign_in_alert" }
      )
    end

    private

    def send_notification(payload)
      return false if @disabled

      Rails.logger.info("[OneSignal] Payload: #{payload.to_json}")

      response = RestClient.post(
        "https://api.onesignal.com/notifications",
        payload.to_json,
        {
          content_type: :json,
          accept: :json,
          Authorization: "Key #{@api_key}"
        }
      )

      Rails.logger.info("[OneSignal] Response: #{response.body}")

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("[OneSignal] API Error: #{e.response&.body}")
      raise PushNotiService::Error, "[OneSignal] API error: #{e.message}"
    rescue => e
      Rails.logger.error("[OneSignal] Unexpected Error: #{e.message}")
      raise
    end

    def handle_error(error, method, context = {})
      Rails.logger.error("[OneSignal] #{method} failed: #{error.message}")
      Rails.logger.error("[OneSignal] Context: #{context.inspect}")
      # Don't re-raise - just return false
      false
    end
  end

  class Error < StandardError; end
end
