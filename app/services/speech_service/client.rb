# app/services/speech_service/client.rb

module SpeechService
  class Client
    class << self
      delegate :speech_to_text_from_file,
               :speech_to_text_from_url,
               to: :provider

      delegate :text_to_speech,
               :start_live_stt,
               to: :azure_provider

      def enqueue_message_tts(message)
        message.tts_status = Chat::Message::STATUSES[:queued]
        message.tts_error = nil
        message.save!

        job = Speech::ProcessTtsJob.perform_later(message.id)
        { message: message, job_id: job.job_id }
      end

      private

      def provider
        @provider ||= NovaSpeech.new
      end

      def azure_provider
        @azure_provider ||= AzureSpeech.new
      end
    end
  end
end
