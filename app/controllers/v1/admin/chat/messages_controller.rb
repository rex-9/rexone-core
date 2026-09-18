# frozen_string_literal: true

# app/controllers/v1/admin/chat/messages_controller.rb
class V1::Admin::Chat::MessagesController < V1::ApplicationController
  before_action :set_active_message, only: %i[show update discard destroy]
  before_action :set_message_including_discarded, only: %i[undiscard]

  def permission_resource_name
    IamConstants::Resource::CHAT_MESSAGES
  end

  # GET /v1/admin/chat/messages
  def index
    messages = Chat::MessageService.admin_list(filter_params)
    pagy, records = pagy(:offset, messages, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGES_RETRIEVED),
      data: Chat::MessageSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/chat/messages/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_RETRIEVED),
      data: Chat::MessageSerializer.new(@message).serializable_hash[:data]
    )
  end

  # PATCH/PUT /v1/admin/chat/messages/:id
  def update
    if @message.update(message_params)
      render_json_response(
        status_code: 200,
        message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_UPDATED),
        data: Chat::MessageSerializer.new(@message).serializable_hash[:data]
      )
    else
      render_json_response(
        status_code: 422,
        message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_UPDATE_FAILED),
        error: @message.errors.full_messages.to_sentence
      )
    end
  end

  # POST /v1/admin/chat/messages/:id/discard
  def discard
    Chat::MessageService.discard!(@message)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_DELETED)
    )
  end

  # POST /v1/admin/chat/messages/:id/undiscard
  def undiscard
    Chat::MessageService.undiscard!(@message)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_UPDATED),
      data: Chat::MessageSerializer.new(@message).serializable_hash[:data]
    )
  end

  # DELETE /v1/admin/chat/messages/:id
  def destroy
    Chat::MessageService.destroy!(@message)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_DELETED)
    )
  end

  private

  def set_active_message
    @message = Chat::MessageService.find(id_params[:id], with_discarded: false)
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND),
      error: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND)
    )
  end

  def set_message_including_discarded
    @message = Chat::MessageService.find(id_params[:id], with_discarded: true)
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND),
      error: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND)
    )
  end

  def id_params
    params.permit(:id)
  end

  def index_params
    params.permit(:limit)
  end

  def filter_params
    params.permit(:room_id, :role, :search, :discarded, :sort_by, :sort_order)
  end

  def message_params
    permitted = params.require(:message).permit(:content, :role)
    valid_roles = AiConstants::ChatRole.constants.map { |c| AiConstants::ChatRole.const_get(c) }
    permitted.delete(:role) unless permitted[:role].in?(valid_roles)
    permitted
  end

  def admin_chat_message(key, **options)
    MessageService::Admin::Chat.t(key, **options)
  end
end
