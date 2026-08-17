# app/controllers/v1/ai_controller.rb
class V1::AiController < V1::ApplicationController
  before_action :set_room, only: [ :create_chat, :read_history, :destroy_clear, :update_rename ]

  # POST /ai/chat
  def create_chat
    message = params[:message]

    if message.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::MESSAGE_REQUIRED),
        error: ai_message(MessageService::Ai::MESSAGE_PARAMETER_MISSING)
      )
      return
    end

    user_message = nil
    job = nil

    @room.with_lock do
      if @room.processing?
        render_json_response(
          status_code: 422,
          message: ai_message(MessageService::Ai::ALREADY_PROCESSING),
          error: ai_message(MessageService::Ai::ALREADY_PROCESSING),
          data: { processing: true, room_id: @room.id }
        )
        return
      end

      user_message = @room.messages.create!(
        role: "user",
        content: message,
        ai_status: Chat::Message::AI_STATUSES[:queued],
        ai_notification_locale: I18n.locale.to_s,
        ai_system_prompt: params[:system_prompt].presence,
        ai_temperature: params[:temperature]&.to_f || 0.7,
        ai_max_tokens: params[:max_tokens]&.to_i || 2000
      )

      job = Ai::ProcessChatJob.perform_later(user_message.id)
    end

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::RESPONSE_QUEUED),
      data: {
        message: Chat::MessageSerializer.new(user_message).serializable_hash[:data][:attributes],
        room_id: @room.id,
        status: "queued",
        job_id: job.job_id
      }
    )

  rescue SolidQueue::Job::EnqueueError, ActiveJob::EnqueueError => error
    Rails.error.report(error)
    render_json_response(
      status_code: 503,
      message: ai_message(MessageService::Ai::QUEUE_FAILED),
      error: ai_message(MessageService::Ai::QUEUE_FAILED)
    )
  end

  # GET /ai/history
  def read_history
    messages = @room.messages.chronological

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::CONVERSATION_HISTORY),
      data: {
        messages: Chat::MessageSerializer.new(messages).serializable_hash[:data],
        room_id: @room.id,
        room_title: @room.title,
        processing: @room.processing?
      }
    )
  end

  # DELETE /ai/clear
  def destroy_clear
    return render_room_busy if @room.processing?

    @room.messages.destroy_all

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::CONVERSATION_CLEARED)
    )
  end

  # PUT /ai/rename
  def update_rename
    title = params[:title]

    if title.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::TITLE_REQUIRED),
        error: ai_message(MessageService::Ai::TITLE_PARAMETER_MISSING)
      )
      return
    end

    @room.update(title: title)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOM_RENAMED),
      data: {
        room: Chat::RoomSerializer.new(@room).serializable_hash[:data][:attributes]
      }
    )
  end

  # GET /ai/rooms
  def read_rooms
    rooms = current_user.rooms.recent.includes(:messages)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOMS_FETCHED),
      data: {
        rooms: Chat::RoomSerializer.new(rooms).serializable_hash[:data]
      }
    )
  end

  # POST /ai/rooms
  def create_room
    room = current_user.rooms.create!(
      title: params[:title] || ai_message(MessageService::Ai::DEFAULT_ROOM_TITLE)
    )

    render_json_response(
      status_code: 201,
      message: ai_message(MessageService::Ai::ROOM_CREATED),
      data: {
        room: Chat::RoomSerializer.new(room).serializable_hash[:data][:attributes]
      }
    )
  end

  # DELETE /ai/rooms/:id
  def destroy_room
    room = current_user.rooms.find(params[:id])
    return render_room_busy if room.processing?

    room.destroy

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::ROOM_DELETED)
    )
  end

  # POST /ai/summarize
  def create_summarize
    text = params[:text]

    if text.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::TEXT_REQUIRED),
        error: ai_message(MessageService::Ai::TEXT_PARAMETER_MISSING)
      )
      return
    end

    messages = [
      { role: "system", content: "Summarize the following text concisely:" },
      { role: "user", content: text }
    ]

    result = AiService::Client.chat(
      messages: messages,
      temperature: 0.5,
      max_tokens: 500
    )

    if result[:error]
      render_json_response(
        status_code: 500,
        message: ai_message(MessageService::Ai::SERVICE_ERROR),
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") ||
                      ai_message(MessageService::Ai::NO_RESPONSE)

      render_json_response(
        status_code: 200,
        message: ai_message(MessageService::Ai::SUMMARY_GENERATED),
        data: { summary: response_text }
      )
    end
  end

  # POST /ai/translate
  def create_translate
    text = params[:text]
    target_language = params[:target_language] || "English"

    if text.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::TEXT_REQUIRED),
        error: ai_message(MessageService::Ai::TEXT_PARAMETER_MISSING)
      )
      return
    end

    messages = [
      { role: "system", content: "Translate the following text to #{target_language}:" },
      { role: "user", content: text }
    ]

    result = AiService::Client.chat(
      messages: messages,
      temperature: 0.3,
      max_tokens: 1000
    )

    if result[:error]
      render_json_response(
        status_code: 500,
        message: ai_message(MessageService::Ai::SERVICE_ERROR),
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") ||
                      ai_message(MessageService::Ai::NO_RESPONSE)

      render_json_response(
        status_code: 200,
        message: ai_message(MessageService::Ai::TRANSLATION_GENERATED),
        data: { translation: response_text }
      )
    end
  end

  # POST /ai/analyze
  def create_analyze
    text = params[:text]
    analysis_type = params[:type] || "sentiment"

    if text.blank?
      render_json_response(
        status_code: 422,
        message: ai_message(MessageService::Ai::TEXT_REQUIRED),
        error: ai_message(MessageService::Ai::TEXT_PARAMETER_MISSING)
      )
      return
    end

    system_prompt = case analysis_type
    when "sentiment"
      "Analyze the sentiment of the following text. Return JSON with: sentiment (positive/negative/neutral), confidence (0-100), and key_emotions (array)."
    when "entities"
      "Extract named entities from the following text. Return JSON with: people, places, organizations, dates."
    when "keywords"
      "Extract key topics and keywords from the following text. Return JSON with: topics (array), keywords (array)."
    else
      "Analyze the following text and provide insights:"
    end

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: text }
    ]

    result = AiService::Client.chat(
      messages: messages,
      temperature: 0.3,
      max_tokens: 500
    )

    if result[:error]
      render_json_response(
        status_code: 500,
        message: ai_message(MessageService::Ai::SERVICE_ERROR),
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") ||
                      ai_message(MessageService::Ai::NO_RESPONSE)

      render_json_response(
        status_code: 200,
        message: ai_message(MessageService::Ai::ANALYSIS_GENERATED),
        data: { analysis: response_text }
      )
    end
  end

  private

  def ai_message(key, **options)
    MessageService::Ai.t(key, **options)
  end

  def set_room
    room_id = params[:room_id]

    if room_id.present?
      @room = current_user.rooms.find(room_id)
    else
      @room = current_user.rooms.first_or_create(
        title: ai_message(MessageService::Ai::DEFAULT_ROOM_TITLE)
      )
    end
  end

  def render_room_busy
    render_json_response(
      status_code: 422,
      message: ai_message(MessageService::Ai::ROOM_BUSY),
      error: ai_message(MessageService::Ai::ROOM_BUSY)
    )
  end
end
