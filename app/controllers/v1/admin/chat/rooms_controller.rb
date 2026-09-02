class V1::Admin::Chat::RoomsController < V1::ApplicationController
  before_action :set_active_room, only: %i[show update discard]
  before_action :set_room_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/chat/rooms
  def index
    rooms = if params[:discarded].to_s == "true"
      ::Chat::Room.with_discarded.discarded.includes(:user, :messages)
    else
      ::Chat::Room.kept.includes(:user, :messages)
    end
    rooms = sort(rooms, columns: SortConstants::Columns::CHAT_ROOM)
    pagy, records = pagy(rooms)

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

  # POST /v1/admin/chat/rooms/:id/discard
  def discard
    @room.discard!

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_DELETED)
    )
  end

  # POST /v1/admin/chat/rooms/:id/undiscard
  def undiscard
    @room.undiscard!

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_UPDATED),
      data: ::Chat::RoomSerializer.new(@room).serializable_hash[:data][:attributes]
    )
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

  def set_active_room
    @room = ::Chat::Room.find(params[:id])
  end

  def set_room_including_discarded
    @room = ::Chat::Room.with_discarded.find(params[:id])
  end

  def room_params
    params.require(:room).permit(:title)
  end

  def admin_chat_message(key, **options)
    MessageService::Admin::Chat.t(key, **options)
  end
end
