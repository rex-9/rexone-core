class V1::Admin::Chat::MessagesController < V1::ApplicationController
  before_action :set_message, only: %i[show update destroy]

  # GET /v1/admin/chat/messages
  def index
    messages = Chat::Message.includes(:room).order(created_at: :desc)
    pagy, records = pagy(:offset, messages, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::CHAT_MESSAGES_RETRIEVED,
      data: Chat::MessageSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/chat/messages/:id
  def show
    render_json_response(
      status_code: 200,
      message: AdminApiMessages::CHAT_MESSAGE_RETRIEVED,
      data: {
        message: Chat::MessageSerializer.new(@message).serializable_hash[:data][:attributes]
      }
    )
  end

  # PATCH/PUT /v1/admin/chat/messages/:id
  def update
    if @message.update(message_params)
      render_json_response(
        status_code: 200,
        message: AdminApiMessages::CHAT_MESSAGE_UPDATED,
        data: {
          message: Chat::MessageSerializer.new(@message).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: AdminApiMessages::CHAT_MESSAGE_UPDATE_FAILED,
        error: @message.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /v1/admin/chat/messages/:id
  def destroy
    @message.destroy

    render_json_response(
      status_code: 200,
      message: AdminApiMessages::CHAT_MESSAGE_DELETED
    )
  end

  private

  def set_message
    @message = Chat::Message.find(params[:id])
  end

  def message_params
    params.require(:message).permit(:role, :content)
  end
end
