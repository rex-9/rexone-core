class V1::Admin::Chat::MessagesController < V1::ApplicationController
  before_action :set_active_message, only: %i[show update discard]
  before_action :set_message_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/chat/messages
  def index
    messages = if params[:discarded].to_s == "true"
      ::Chat::Message.with_discarded.discarded.includes(:room)
    else
      ::Chat::Message.kept.includes(:room)
    end
    messages = sort(messages, columns: SortConstants::Columns::CHAT_MSG)
    pagy, records = pagy(messages)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGES_RETRIEVED),
      data: ::Chat::MessageSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/chat/messages/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_RETRIEVED),
      data: ::Chat::MessageSerializer.new(@message).serializable_hash[:data][:attributes]
    )
  end

  # PATCH/PUT /v1/admin/chat/messages/:id
  def update
    if @message.update(message_params)
      render_json_response(
        status_code: 200,
        message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_UPDATED),
        data: ::Chat::MessageSerializer.new(@message).serializable_hash[:data][:attributes]
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
    @message.discard!

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_DELETED)
    )
  end

  # POST /v1/admin/chat/messages/:id/undiscard
  def undiscard
    @message.undiscard!

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_UPDATED),
      data: ::Chat::MessageSerializer.new(@message).serializable_hash[:data][:attributes]
    )
  end

  # DELETE /v1/admin/chat/messages/:id
  def destroy
    @message.destroy

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::MESSAGE_DELETED)
    )
  end

  private

  def set_active_message
    @message = ::Chat::Message.find(params[:id])
  end

  def set_message_including_discarded
    @message = ::Chat::Message.with_discarded.find(params[:id])
  end

  def message_params
    params.require(:message).permit(:role, :content)
  end

  def admin_chat_message(key, **options)
    MessageService::Admin::Chat.t(key, **options)
  end
end
