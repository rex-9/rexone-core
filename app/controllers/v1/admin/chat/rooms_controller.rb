class V1::Admin::Chat::RoomsController < V1::ApplicationController
  before_action :set_room, only: %i[show update destroy]

  # GET /v1/admin/chat/rooms
  def index
    rooms = ::Chat::Room.includes(:user, :messages).order(created_at: :desc)
    pagy, records = pagy(:offset, rooms, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOMS_RETRIEVED),
      data: ::Chat::RoomSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/chat/rooms/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_RETRIEVED),
      data: ::Chat::RoomSerializer.new(@room).serializable_hash[:data][:attributes]
    )
  end

  # PATCH/PUT /v1/admin/chat/rooms/:id
  def update
    if @room.update(room_params)
      render_json_response(
        status_code: 200,
        message: admin_chat_message(MessageService::Admin::Chat::ROOM_UPDATED),
        data: ::Chat::RoomSerializer.new(@room).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: admin_chat_message(MessageService::Admin::Chat::ROOM_UPDATE_FAILED),
        error: @room.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /v1/admin/chat/rooms/:id
  def destroy
    @room.destroy

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_DELETED)
    )
  end

  private

  def set_room
    @room = ::Chat::Room.find(params[:id])
  end

  def room_params
    params.require(:room).permit(:title)
  end

  def admin_chat_message(key, **options)
    MessageService::Admin::Chat.t(key, **options)
  end
end
