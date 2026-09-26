# frozen_string_literal: true

# app/controllers/v1/chat/rooms_controller.rb
class V1::Chat::RoomsController < V1::ApplicationController
  before_action :set_room, only: %i[show update destroy]

  # GET /v1/chat/rooms
  def index
    rooms = Chat::RoomService.list(current_user)
    pagy, records = pagy(:offset, rooms, limit: index_params[:limit])

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOMS_FETCHED),
      **Chat::RoomSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/chat/rooms/:id
  def show
    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOM_FETCHED),
      data: Chat::RoomSerializer.record(@room)
    )
  end

  # POST /v1/chat/rooms
  def create
    title = room_params[:title]
    room = Chat::RoomService.create!(current_user, title: title)

    render_json_response(
      status_code: 201,
      message: ai_message(MessageService::Ai::ROOM_CREATED),
      data: Chat::RoomSerializer.record(room)
    )
  end

  # PUT /v1/chat/rooms/:id
  def update
    title = room_params[:title]
    if title.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::TITLE_REQUIRED),
        error: ai_message(MessageService::Ai::TITLE_PARAMETER_MISSING)
      )
      return
    end

    room = Chat::RoomService.update!(@room, title: title)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOM_RENAMED),
      data: Chat::RoomSerializer.record(room)
    )
  end

  # DELETE /v1/chat/rooms/:id
  def destroy
    Chat::RoomService.destroy!(@room)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOM_DELETED)
    )
  rescue Chat::RoomService::RoomBusyError => error
    render_json_response(
      status_code: 422,
      message: error.message,
      error: error.message
    )
  end

  private

  def index_params
    params.permit(:limit, :page)
  end

  def set_room
    @room = Chat::RoomService.find(current_user, params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: ai_message(MessageService::Ai::NOT_FOUND),
      error: ai_message(MessageService::Ai::NOT_FOUND)
    )
  end

  def room_params
    params.permit(:title)
  end

  def permission_resource_name
    IamConstants::Resource::CHAT_ROOMS
  end

  def ai_message(key, **options)
    MessageService::Ai.t(key, **options)
  end
end
