# frozen_string_literal: true

# app/controllers/v1/admin/chat/rooms_controller.rb
class V1::Admin::Chat::RoomsController < V1::ApplicationController
  before_action :set_active_room, only: %i[show update discard destroy]
  before_action :set_room_including_discarded, only: %i[undiscard]

  def permission_resource_name
    IamConstants::Resource::CHAT_ROOMS
  end

  # GET /v1/admin/chat/rooms
  def index
    filters = list_params
    rooms = Chat::RoomService.admin_list(filters)
    pagy, records = pagy(:offset, rooms, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOMS_RETRIEVED),
      data: Chat::RoomSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/chat/rooms/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_RETRIEVED),
      data: Chat::RoomSerializer.new(@room).serializable_hash[:data]
    )
  end

  # PATCH/PUT /v1/admin/chat/rooms/:id
  def update
    if @room.update(room_params)
      render_json_response(
        status_code: 200,
        message: admin_chat_message(MessageService::Admin::Chat::ROOM_UPDATED),
        data: Chat::RoomSerializer.new(@room).serializable_hash[:data]
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
    Chat::RoomService.discard!(@room)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_DELETED)
    )
  rescue Chat::RoomService::RoomBusyError => error
    render_json_response(
      status_code: 422,
      message: error.message,
      error: error.message
    )
  end

  # POST /v1/admin/chat/rooms/:id/undiscard
  def undiscard
    Chat::RoomService.undiscard!(@room)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_UPDATED),
      data: Chat::RoomSerializer.new(@room).serializable_hash[:data]
    )
  end

  # DELETE /v1/admin/chat/rooms/:id
  def destroy
    Chat::RoomService.destroy!(@room)

    render_json_response(
      status_code: 200,
      message: admin_chat_message(MessageService::Admin::Chat::ROOM_DELETED)
    )
  rescue Chat::RoomService::RoomBusyError => error
    render_json_response(
      status_code: 422,
      message: error.message,
      error: error.message
    )
  end

  private

  def list_params
    params.permit(:discarded, :user_id, :limit, :page)
  end

  def set_active_room
    @room = Chat::RoomService.admin_find(params.permit(:id)[:id], with_discarded: false)
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND),
      error: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND)
    )
  end

  def set_room_including_discarded
    @room = Chat::RoomService.admin_find(params.permit(:id)[:id], with_discarded: true)
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND),
      error: admin_chat_message(MessageService::Admin::Chat::NOT_FOUND)
    )
  end

  def room_params
    params.require(:room).permit(:title)
  end

  def admin_chat_message(key, **options)
    MessageService::Admin::Chat.t(key, **options)
  end
end
