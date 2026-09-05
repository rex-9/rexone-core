# app/services/push_noti_service/one_signal.rb
require "rest-client"

module PushNotiService
  class OneSignal < Base
    LOG_PREFIX = "[OneSignal]".freeze

    def initialize
      @app_id = AppConfig::ONE_SIGNAL_APP_ID
      @api_key = AppConfig::ONE_SIGNAL_API_KEY
      @default_sound = AppConfig::ONE_SIGNAL_DEFAULT_SOUND

      if @app_id.blank? || @api_key.blank?
        Rails.logger.info("#{LOG_PREFIX} not configured - push notifications disabled")
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
        target_channel: NotificationConstants::Channel::PUSH
      }

      send_notification(payload)
    rescue => e
      handle_error(e, "send_to_device", subscription_id: subscription_id)
      false
    end

    # Send to all devices belonging to a user (external_id)
    def send_to_user(user_id:, title: nil, body: nil, data: {}, sound: nil, template_id: nil, **kwargs)
      payload = {
        app_id: @app_id,
        include_aliases: {
          external_id: [ user_id ]
        },
        target_channel: NotificationConstants::Channel::PUSH,
        headings: title ? { en: title } : nil,
        contents: body ? { en: body } : nil,
        data: data,
        android_sound: sound || @default_sound,
        ios_sound: sound || @default_sound,
        template_id: template_id
      }.compact

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
        target_channel: NotificationConstants::Channel::PUSH,
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

    private

    def send_notification(payload)
      return { "disabled" => true } if @disabled

      Rails.logger.info("#{LOG_PREFIX} Payload: #{payload.to_json}")

      response = RestClient.post(
        "https://api.onesignal.com/notifications",
        payload.to_json,
        {
          content_type: :json,
          accept: :json,
          Authorization: "Key #{@api_key}"
        }
      )

      Rails.logger.info("#{LOG_PREFIX} Response: #{response.body}")

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("#{LOG_PREFIX} API Error: #{e.response&.body}")
      raise PushNotiService::Error, "#{LOG_PREFIX} API error: #{e.message}"
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Unexpected Error: #{e.message}")
      raise
    end

    def handle_error(error, method, context = {})
      Rails.logger.error("#{LOG_PREFIX} #{method} failed: #{error.message}")
      Rails.logger.error("#{LOG_PREFIX} Context: #{context.inspect}")
      # Don't re-raise - just return false
      false
    end
  end

  class Error < StandardError; end
end
