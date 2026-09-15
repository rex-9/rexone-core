# frozen_string_literal: true

# app/services/chat/message_service.rb
module Chat
  class MessageService
    Error = Class.new(StandardError)

    class Result
      attr_reader :message, :job, :operation_id, :link, :messages

      def initialize(message:, job: nil, operation_id: nil, link: nil, messages: nil)
        @message = message
        @job = job
        @operation_id = operation_id
        @link = link
        @messages = messages || [ message ].compact
      end
    end

    LOG_PREFIX = "[Chat]".freeze

    class << self
      def list(room, params = {})
        room.messages.chronological.includes(assets: %i[thumbnail subtitles])
      end

      def admin_list(params = {})
        scope = if params[:discarded].to_s == "true"
                  ::Chat::Message.with_discarded.discarded.includes(:room)
        else
                  ::Chat::Message.kept.includes(:room)
        end

        scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?
        scope = scope.where(role: params[:role]) if params[:role].present?
        scope = scope.joins(:room).where(chat_rooms: { user_id: params[:user_id] }) if params[:user_id].present?
        scope.order(SortConstants::Columns::CHAT_MSG.first => SortConstants::Order::DESC)
      end

      def find(id, with_discarded: false)
        scope = with_discarded ? ::Chat::Message.with_discarded : ::Chat::Message.kept
        scope.find(id)
      end

      def update!(message, attributes)
        message.update!(attributes)
        message
      end

      def discard!(message)
        message.discard!
        message
      end

      def undiscard!(message)
        message.undiscard!
        message
      end

      def destroy!(message)
        message.destroy!
      end

      def clear_history!(room)
        raise Error, ::MessageService::Ai.t(::MessageService::Ai::ROOM_BUSY) if room.processing?

        room.messages.destroy_all
      end

      def send_user_message!(user:, room:, content:)
        chunks = Chat::TextService.chunk(content)
        split_id = chunks.size > 1 ? SecureRandom.uuid : nil
        messages = []

        room.with_lock do
          chunks.each_with_index do |chunk_text, index|
            metadata = {}
            if split_id
              metadata[AiConstants::ChunkMetadata::SPLIT_ID] = split_id
              metadata[AiConstants::ChunkMetadata::CHUNK_INDEX] = index
              metadata[AiConstants::ChunkMetadata::TOTAL_CHUNKS] = chunks.size
            end

            msg = room.messages.create!(
              role: AiConstants::ChatRole::USER,
              content: chunk_text,
              metadata: metadata
            )
            messages << msg
          end
          room.update_title_from_first_message! if default_room_title?(room)
        end

        messages.size > 1 ? messages : messages.first
      end

      def queue_ai_response!(user:, room:, content:, profile_key: nil)
        profile = Ai::ProfileService.resolve!(profile_key)
        chunks = Chat::TextService.chunk(content)
        split_id = chunks.size > 1 ? SecureRandom.uuid : nil
        messages = []
        message = nil
        job = nil
        operation_id = nil
        link = nil

        room.with_lock do
          raise Error, ::MessageService::Ai.t(::MessageService::Ai::ALREADY_PROCESSING) if room.processing?

          chunks.each_with_index do |chunk_text, index|
            is_last = (index == chunks.size - 1)
            metadata = {}
            if split_id
              metadata[AiConstants::ChunkMetadata::SPLIT_ID] = split_id
              metadata[AiConstants::ChunkMetadata::CHUNK_INDEX] = index
              metadata[AiConstants::ChunkMetadata::TOTAL_CHUNKS] = chunks.size
            end

            if is_last
              metadata["status"] = Chat::Message::STATUSES[:queued]
              metadata["system_prompt"] = profile.system_prompt
              metadata["temperature"] = profile.temperature.to_f
              metadata["max_tokens"] = profile.max_output_tokens

              message = room.messages.create!(
                role: AiConstants::ChatRole::USER,
                content: chunk_text,
                metadata: metadata,
                ai_profile: profile
              )
            else
              message = room.messages.create!(
                role: AiConstants::ChatRole::USER,
                content: chunk_text,
                metadata: metadata
              )
            end
            messages << message
          end

          job = Chat::ProcessMessageJob.perform_later(message.id)
          operation_id = operation_id_for(message)
          link = link_for(room)

          ::NotificationService::Center.operation(
            user_id: user.id,
            operation_id: operation_id,
            operation_type: NotificationConstants::OperationType::AI_RESPONSE,
            operation_status: NotificationConstants::OperationStatus::QUEUED,
            message: ::MessageService::Ai.t(::MessageService::Ai::RESPONSE_QUEUED),
            link: link,
            data: {
              type: NotificationConstants::NotificationType::AI_RESPONSE_READY,
              room_id: room.id,
              message_id: message.id
            }
          )
        end

        Result.new(message: message, job: job, operation_id: operation_id, link: link, messages: messages)
      end

      def process_ai_response!(message_id)
        message = Chat::Message.find(message_id)
        return if message.ai_status == Chat::Message::STATUSES[:completed]

        update_status!(message, Chat::Message::STATUSES[:processing])
        notify_operation(
          message,
          NotificationConstants::OperationStatus::PROCESSING,
          ::MessageService::Ai.t(::MessageService::Ai::RESPONSE_QUEUED)
        )

        result = Ai::RunService.execute_chat(
          user: message.room.user,
          feature: AiConstants::RunFeature::CHAT,
          profile_key: message.ai_profile&.key || AiConstants::ProfileKey::CHAT_DEFAULT,
          messages: conversation_for(message),
          chat_message: message,
          request_metadata: { AiConstants::RequestMetadata::ROOM_ID => message.room_id }
        )

        raise Ai::Providers::Error, result[:error] if result[:error].present?

        choice = result.dig("choices", 0) || {}
        message_obj = choice["message"] || {}
        response = message_obj["content"].presence || message_obj["reasoning_content"]
        raise Ai::Providers::Error, ::MessageService::Ai.t(::MessageService::Ai::NO_RESPONSE) if response.blank?

        assistant_message = persist_response!(message, response, result)
        notify_completed(message, assistant_message)
      rescue Ai::Providers::Error => error
        update_status!(message, Chat::Message::STATUSES[:retrying], error: error.message) if message.present?
        raise
      rescue StandardError => error
        fail_ai_response!(message_id, error)
        raise
      end

      def fail_ai_response!(message_id, error)
        message = Chat::Message.find_by(id: message_id)
        return unless message
        return if message.ai_status == Chat::Message::STATUSES[:completed]

        update_status!(message, Chat::Message::STATUSES[:failed], error: error.message)

        room = message.room
        alert = ::MessageService::Ai.t(::MessageService::Ai::RESPONSE_FAILED)
        data = {
          type: NotificationConstants::NotificationType::AI_RESPONSE_FAILED,
          room_id: room.id,
          message_id: message.id,
          error: error.message
        }

        ::NotificationService::Center.notify(
          user_id: room.user_id,
          title: alert,
          message: alert,
          data: data,
          operation_id: operation_id_for(message),
          operation_type: NotificationConstants::OperationType::AI_RESPONSE,
          operation_status: NotificationConstants::OperationStatus::FAILED,
          link: link_for(room),
          send_push: false,
          send_socket: true,
          send_email: false
        )
      end

      private

      def operation_id_for(message)
        "ai_response:#{message.id}"
      end

      def link_for(room)
        "/ai?room_id=#{room.id}"
      end

      def update_status!(message, status, error: nil)
        message.ai_status = status
        message.ai_error = error if error.present?
        message.save!
      end

      def conversation_for(message)
        history_limit = message.ai_profile&.history_max_messages || AiConstants::Defaults::HISTORY_MAX_MESSAGES
        history = message.room.messages
                         .where("created_at < :time OR (created_at = :time AND id < :id)", time: message.created_at, id: message.id)
                         .chronological
                         .last(history_limit)

        all_messages = history + [ message ]

        grouped = []
        all_messages.each do |msg|
          split_id = msg.metadata&.dig(AiConstants::ChunkMetadata::SPLIT_ID)
          if split_id.present? && grouped.last && grouped.last[:split_id] == split_id && grouped.last[:role] == msg.role
            grouped.last[:content] = "#{grouped.last[:content]}\n\n#{msg.content}"
          else
            grouped << {
              role: msg.role,
              content: msg.content,
              split_id: split_id
            }
          end
        end

        payload = grouped.map { |item| { role: item[:role], content: item[:content] } }

        system_prompt = message.ai_system_prompt.presence || message.ai_profile&.system_prompt
        payload.unshift(role: AiConstants::ChatRole::SYSTEM, content: system_prompt) if system_prompt.present?

        payload
      end

      def default_room_title?(room)
        room.title == ::MessageService::Ai.t(::MessageService::Ai::DEFAULT_ROOM_TITLE)
      end

      def persist_response!(user_message, response_text, result)
        chunks = Chat::TextService.chunk(response_text)
        split_id = chunks.size > 1 ? SecureRandom.uuid : nil
        assistant_messages = []
        usage = result["usage"] || {}
        model = result["model"] || user_message.ai_profile&.model

        Chat::Message.transaction do
          chunks.each_with_index do |chunk_text, index|
            metadata = {
              "status" => Chat::Message::STATUSES[:completed],
              "model" => model
            }
            if split_id
              metadata[AiConstants::ChunkMetadata::SPLIT_ID] = split_id
              metadata[AiConstants::ChunkMetadata::CHUNK_INDEX] = index
              metadata[AiConstants::ChunkMetadata::TOTAL_CHUNKS] = chunks.size
            end
            metadata["usage"] = usage if index == 0

            msg = user_message.room.messages.create!(
              role: AiConstants::ChatRole::ASSISTANT,
              content: chunk_text,
              ai_profile: user_message.ai_profile,
              metadata: metadata
            )
            assistant_messages << msg
          end

          user_message.ai_assistant_message_id = assistant_messages.first.id
          user_message.ai_status = Chat::Message::STATUSES[:completed]
          user_message.ai_error = nil
          user_message.save!

          room = user_message.room
          room.update_title_from_first_message! if default_room_title?(room)
        end

        assistant_messages.size > 1 ? assistant_messages : assistant_messages.first
      end

      def notify_operation(message, status, text, error: nil)
        payload_data = {
          room_id: message.room_id,
          message_id: message.id
        }
        payload_data[:error] = error if error.present?

        ::NotificationService::Center.operation(
          user_id: message.room.user_id,
          operation_id: operation_id_for(message),
          operation_type: NotificationConstants::OperationType::AI_RESPONSE,
          operation_status: status,
          message: text,
          link: link_for(message.room),
          data: payload_data
        )
      end

      def notify_completed(user_message, assistant_response)
        room = user_message.room
        message_text = ::MessageService::Ai.t(::MessageService::Ai::RESPONSE_READY)
        first_message = assistant_response.is_a?(Array) ? assistant_response.first : assistant_response
        message_ids = assistant_response.is_a?(Array) ? assistant_response.map(&:id) : [ assistant_response.id ]

        data = {
          type: NotificationConstants::NotificationType::AI_RESPONSE_READY,
          room_id: room.id,
          message_id: first_message.id,
          message_ids: message_ids
        }

        ::NotificationService::Center.notify(
          user_id: room.user_id,
          title: message_text,
          message: message_text,
          data: data,
          operation_id: operation_id_for(user_message),
          operation_type: NotificationConstants::OperationType::AI_RESPONSE,
          operation_status: NotificationConstants::OperationStatus::COMPLETED,
          link: link_for(room),
          send_push: false,
          send_socket: true,
          send_email: false
        )
      end
    end
  end
end
