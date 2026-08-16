class Notification::DeliverJob < ApplicationJob
  class DeliveryError < StandardError; end

  queue_as :notifications

  retry_on DeliveryError,
           EmailService::Error,
           wait: :polynomially_longer,
           attempts: 5

  def perform(channel:, payload:)
    result = case channel.to_sym
    when :socket
      SocketService::Client.broadcast(**payload.symbolize_keys)
    when :push
      PushNotiService::Client.send_to_user(**payload.symbolize_keys)
    when :email
      deliver_email(payload.symbolize_keys)
    else
      raise ArgumentError, "Unsupported notification channel: #{channel}"
    end

    raise DeliveryError, "#{channel} delivery failed" unless result
  end

  private

  def deliver_email(payload)
    if payload[:template_id].present?
      EmailService::Client.send_template(**payload)
    else
      EmailService::Client.send_email(**payload)
    end
  end
end
