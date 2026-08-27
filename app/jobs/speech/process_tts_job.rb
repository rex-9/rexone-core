class Speech::ProcessTtsJob < ApplicationJob
  LOG_PREFIX = "[SpeechTTS]".freeze

  queue_as :ai
  queue_with_priority(-10)

  limits_concurrency(
    to: 1,
    key: ->(message_id) { "tts:#{message_id}" },
    duration: 30.minutes
  )

  retry_on SpeechService::Error,
           StorageService::Error,
           wait: :polynomially_longer,
           attempts: 5 do |job, error|
    job.send(:mark_as_failed!, job.arguments.first, error)
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(message_id)
    message = Chat::Message.find(message_id)
    return if message.tts_status == Chat::Message::TTS_STATUSES[:completed]

    update_tts!(message, Chat::Message::TTS_STATUSES[:processing])

    result = SpeechService::Client.text_to_speech(text: message.content)
    raise SpeechService::Error, result[:error] if result[:error].present?

    upload = upload_audio!(message, result)
    update_tts!(
      message,
      Chat::Message::TTS_STATUSES[:completed],
      audio_url: upload[:url],
      tts_error: nil
    )
    notify_completed(message)
  rescue SpeechService::Error, StorageService::Error => error
    update_tts!(message, Chat::Message::TTS_STATUSES[:retrying], tts_error: error.message) if message
    raise
  rescue StandardError => error
    mark_as_failed!(message_id, error)
    raise
  end

  private

  def upload_audio!(message, result)
    Tempfile.create([ "tts-#{message.id}", ".mp3" ]) do |file|
      file.binmode
      file.write(result[:bytes])
      file.rewind

      StorageService::Client.upload(
        file,
        public_id: "message_#{message.id}",
        folder: SpeechConstants::Tts::STORAGE_FOLDER,
        resource_type: SpeechConstants::Tts::STORAGE_RESOURCE_TYPE,
        overwrite: true
      )
    end
  end

  def notify_completed(message)
    copy = speech_message(MessageService::Speech::TTS_READY)
    NotificationService.notify(
      user_id: message.room.user_id,
      title: copy,
      message: copy,
      data: {
        type: NotificationConstants::NotificationType::TTS_READY,
        room_id: message.room_id,
        message_id: message.id,
        audio_url: message.audio_url
      },
      send_push: false,
      send_socket: true,
      send_email: false
    )
  end

  def mark_as_failed!(message_id, error)
    message = Chat::Message.find_by(id: message_id)
    return unless message
    return if message.tts_status == Chat::Message::TTS_STATUSES[:completed]

    update_tts!(message, Chat::Message::TTS_STATUSES[:failed], tts_error: error.message)

    copy = speech_message(MessageService::Speech::TTS_FAILED)
    NotificationService.notify(
      user_id: message.room.user_id,
      title: copy,
      message: copy,
      data: {
        type: NotificationConstants::NotificationType::TTS_FAILED,
        room_id: message.room_id,
        message_id: message.id
      },
      send_push: false,
      send_socket: true,
      send_email: false
    )

    Rails.logger.error(
      "#{LOG_PREFIX} TTS failed: message_id=#{message_id} #{error.class}: #{error.message}"
    )
  rescue StandardError => tracking_error
    Rails.logger.error(
      "#{LOG_PREFIX} Could not record TTS failure for #{message_id}: " \
      "#{tracking_error.class}: #{tracking_error.message}"
    )
  end

  def update_tts!(message, status, audio_url: :unchanged, tts_error: :unchanged)
    message.tts_status = status
    message.audio_url = audio_url unless audio_url == :unchanged
    message.tts_error = tts_error unless tts_error == :unchanged
    message.save!
  end

  def speech_message(key)
    MessageService::Speech.t(key)
  end
end
