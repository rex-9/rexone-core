# frozen_string_literal: true

# app/controllers/v1/chat/messages_controller.rb
class V1::Chat::MessagesController < V1::ApplicationController
  before_action :set_room, only: %i[index create destroy_all]
  before_action :set_message, only: %i[show update destroy]

  # GET /v1/chat/messages
  def index
    messages = Chat::MessageService.list(@room)
    pagy, records = pagy(:offset, messages, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::CONVERSATION_HISTORY),
      **Chat::MessageSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/chat/messages/:id
  def show
    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::MESSAGE_FETCHED),
      data: Chat::MessageSerializer.record(@message)
    )
  end

  # POST /v1/chat/messages
  def create
    content = create_params[:message]
    if content.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::MESSAGE_REQUIRED),
        error: ai_message(MessageService::Ai::MESSAGE_PARAMETER_MISSING)
      )
      return
    end

    if create_params[:ai].to_s == "false"
      result = Chat::MessageService.send_user_message!(
        user: current_user,
        room: @room,
        content: content
      )
      all_messages = Array.wrap(result)
      primary_message = all_messages.first
      serialized_messages = Chat::MessageSerializer.collection(all_messages)

      render_json_response(
        status_code: 201,
        message: ai_message(MessageService::Ai::MESSAGE_SENT),
        data: Chat::MessageSerializer.record(primary_message),
        meta: {
          room_id: @room.id,
          messages: serialized_messages
        }
      )
    else
      result = Chat::MessageService.queue_ai_response!(
        user: current_user,
        room: @room,
        content: content,
        profile_key: create_params[:profile_key]
      )
      serialized_messages = Chat::MessageSerializer.collection(result.messages)

      render_json_response(
        status_code: 202,
        message: ai_message(MessageService::Ai::RESPONSE_QUEUED),
        data: Chat::MessageSerializer.record(result.message),
        meta: {
          room_id: @room.id,
          status: NotificationConstants::OperationStatus::QUEUED,
          operation_id: result.operation_id,
          operation_type: NotificationConstants::OperationType::AI_RESPONSE,
          link: result.link,
          job_id: result.job&.job_id,
          messages: serialized_messages
        }
      )
    end
  rescue SolidQueue::Job::EnqueueError, ActiveJob::EnqueueError => error
    Rails.error.report(error)
    render_json_response(
      status_code: 503,
      message: ai_message(MessageService::Ai::QUEUE_FAILED),
      error: ai_message(MessageService::Ai::QUEUE_FAILED)
    )
  rescue Ai::Providers::Error => error
    render_json_response(
      status_code: 422,
      message: ai_message(MessageService::Ai::SERVICE_ERROR),
      error: error.message
    )
  rescue Chat::MessageService::Error => error
    render_json_response(
      status_code: 422,
      message: error.message,
      error: error.message,
      meta: { processing: true, room_id: @room.id }
    )
  end

  # PATCH/PUT /v1/chat/messages/:id
  def update
    content = update_params[:content]
    if content.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::MESSAGE_REQUIRED),
        error: ai_message(MessageService::Ai::MESSAGE_PARAMETER_MISSING)
      )
      return
    end

    message = Chat::MessageService.update!(@message, content: content)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::MESSAGE_UPDATED),
      data: Chat::MessageSerializer.record(message)
    )
  end

  # DELETE /v1/chat/messages/:id
  def destroy
    Chat::MessageService.discard!(@message)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::MESSAGE_DELETED)
    )
  end

  # DELETE /v1/chat/messages/destroy_all
  def destroy_all
    Chat::MessageService.clear_history!(@room)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::CONVERSATION_CLEARED)
    )
  rescue Chat::MessageService::Error => error
    render_json_response(
      status_code: 422,
      message: error.message,
      error: error.message
    )
  end

  private

  def set_room
    room_id = params.permit(:room_id)[:room_id].presence || (create_params[:room_id].presence if action_name == "create")

    if room_id.present?
      @room = current_user.rooms.kept.find(room_id)
    else
      @room = current_user.rooms.kept.first_or_create!(
        title: ai_message(MessageService::Ai::DEFAULT_ROOM_TITLE)
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: ai_message(MessageService::Ai::NOT_FOUND),
      error: ai_message(MessageService::Ai::NOT_FOUND)
    )
  end

  def index_params
    params.permit(:room_id, :limit, :page)
  end

  def create_params
    params.permit(:message, :room_id, :profile_key, :ai)
  end

  def update_params
    params.permit(:content)
  end

  def set_message
    @message = Chat::MessageService.find(params.permit(:id)[:id])
    if @message.room.user_id != current_user.id
      render_json_response(
        status_code: 404,
        message: ai_message(MessageService::Ai::NOT_FOUND),
        error: ai_message(MessageService::Ai::NOT_FOUND)
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: ai_message(MessageService::Ai::NOT_FOUND),
      error: ai_message(MessageService::Ai::NOT_FOUND)
    )
  end

  def permission_resource_name
    IamConstants::Resource::CHAT_MESSAGES
  end

  def ai_message(key, **options)
    MessageService::Ai.t(key, **options)
  end
end
