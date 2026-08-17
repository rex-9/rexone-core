class Ai::ProcessChatJob < ApplicationJob
  LOG_PREFIX = "[AI]".freeze

  queue_as :ai

  limits_concurrency(
    to: 1,
    key: ->(message_id) { message_id },
    duration: 30.minutes
  )

  retry_on AiService::Error,
           wait: :polynomially_longer,
           attempts: 5 do |job, error|
    job.send(:mark_as_failed!, job.arguments.first, error)
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(message_id)
    user_message = Chat::Message.find(message_id)
    return if user_message.ai_status == Chat::Message::AI_STATUSES[:completed]

    update_status!(user_message, Chat::Message::AI_STATUSES[:processing])

    result = AiService::Client.chat(
      messages: conversation_for(user_message),
      temperature: user_message.ai_temperature || 0.7,
      max_tokens: user_message.ai_max_tokens || 2000
    )

    raise AiService::Error, result[:error] if result[:error].present?

    response = result.dig("choices", 0, "message", "content")
    raise AiService::Error, ai_message(MessageService::Ai::NO_RESPONSE, user_message) if response.blank?

    assistant_message = persist_response!(user_message, response, result)
    notify_completed(user_message, assistant_message)

  rescue AiService::Error => error
    update_status!(user_message, Chat::Message::AI_STATUSES[:retrying], error: error.message) if user_message.present?
    raise
  rescue StandardError => error
    mark_as_failed!(message_id, error)
    raise
  end

  private

  def conversation_for(user_message)
    messages = user_message.room.messages
                           .where("created_at <= ?", user_message.created_at)
                           .order(created_at: :desc)
                           .limit(20)
                           .reverse
                           .map { |message| { role: message.role, content: message.content } }

    system_prompt = user_message.ai_system_prompt
    messages.unshift(role: "system", content: system_prompt) if system_prompt.present?
    messages
  end

  def persist_response!(user_message, response, result)
    assistant_message = nil

    Chat::Message.transaction do
      user_message.lock!
      return if user_message.ai_status == Chat::Message::AI_STATUSES[:completed]

      assistant_message = user_message.room.messages.create!(
        role: "assistant",
        content: response,
        ai_usage: result["usage"],
        ai_model: result["model"]
      )

      update_status!(
        user_message,
        Chat::Message::AI_STATUSES[:completed],
        assistant_message_id: assistant_message.id,
        error: nil
      )

      room = user_message.room
      room.update_title_from_first_message! if default_room_title?(room, user_message)
    end

    assistant_message
  end

  def notify_completed(user_message, assistant_message)
    room = user_message.room
    message = ai_message(MessageService::Ai::RESPONSE_READY, user_message)
    data = {
      type: "ai_response_ready",
      room_id: room.id,
      message_id: assistant_message.id
    }

    NotificationService.notify(
      user_id: room.user_id,
      title: message,
      message: message,
      data: data,
      send_push: false,
      send_socket: true,
      send_email: false
    )
  end

  def mark_as_failed!(message_id, error)
    user_message = Chat::Message.find_by(id: message_id)
    return unless user_message
    return if user_message.ai_status == Chat::Message::AI_STATUSES[:completed]

    update_status!(user_message, Chat::Message::AI_STATUSES[:failed], error: error.message)

    room = user_message.room
    message = ai_message(MessageService::Ai::RESPONSE_FAILED, user_message)
    data = {
      type: "ai_response_failed",
      room_id: room.id,
      message_id: user_message.id
    }

    NotificationService.notify(
      user_id: room.user_id,
      title: message,
      message: message,
      data: data,
      send_push: false,
      send_socket: true,
      send_email: false
    )

    Rails.logger.error(
      "#{LOG_PREFIX} Chat processing failed: " \
      "message_id=#{message_id} #{error.class}: #{error.message}"
    )
  rescue StandardError => tracking_error
    Rails.logger.error(
      "#{LOG_PREFIX} Could not record chat failure for #{message_id}: " \
      "#{tracking_error.class}: #{tracking_error.message}"
    )
  end

  def update_status!(message, status, error: :unchanged, assistant_message_id: :unchanged)
    message.ai_status = status
    message.ai_error = error unless error == :unchanged
    message.ai_assistant_message_id = assistant_message_id unless assistant_message_id == :unchanged
    message.save!
  end

  def default_room_title?(room, message)
    room.title == ai_message(MessageService::Ai::DEFAULT_ROOM_TITLE, message)
  end

  def ai_message(key, message)
    locale = message.ai_notification_locale.presence || I18n.default_locale
    I18n.with_locale(locale) { MessageService::Ai.t(key) }
  end
end
