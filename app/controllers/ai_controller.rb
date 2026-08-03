# app/controllers/ai_controller.rb

class AiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_room, only: [ :chat, :history, :clear, :rename ]

  # POST /ai/chat
  def chat
    message = params[:message]

    if message.blank?
      render_json_response(
        status_code: 422,
        message: "Message is required",
        error: "Missing message parameter"
      )
      return
    end

    # Save user message
    @room.messages.create!(
      role: "user",
      content: message
    )

    # Build messages with history
    messages = build_messages

    result = AiService::Client.chat(
      messages: messages,
      temperature: params[:temperature]&.to_f || 0.7,
      max_tokens: params[:max_tokens]&.to_i || 2000
    )

    if result[:error]
      render_json_response(
        status_code: 500,
        message: "AI service error",
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") || "No response"

      # Save assistant response
      @room.messages.create!(
        role: "assistant",
        content: response_text,
        metadata: {
          usage: result["usage"],
          model: result["model"]
        }
      )

      # Update room title from first message if default
      @room.update_title_from_first_message! if @room.title == "New Conversation"

      render_json_response(
        status_code: 200,
        message: "AI response generated",
        data: {
          response: response_text,
          room_id: @room.id,
          usage: result["usage"]
        }
      )
    end
  end

  # GET /ai/history
  def history
    messages = @room.messages.chronological

    render_json_response(
      status_code: 200,
      message: "Conversation history",
      data: {
        messages: Chat::MessageSerializer.new(messages).serializable_hash[:data],
        room_id: @room.id,
        room_title: @room.title
      }
    )
  end

  # DELETE /ai/clear
  def clear
    @room.messages.destroy_all

    render_json_response(
      status_code: 200,
      message: "Conversation cleared"
    )
  end

  # PUT /ai/rename
  def rename
    title = params[:title]

    if title.blank?
      render_json_response(
        status_code: 422,
        message: "Title is required",
        error: "Missing title parameter"
      )
      return
    end

    @room.update(title: title)

    render_json_response(
      status_code: 200,
      message: "Room renamed",
      data: {
        room: Chat::RoomSerializer.new(@room).serializable_hash[:data][:attributes]
      }
    )
  end

  # GET /ai/rooms
  def rooms
    rooms = current_user.chat_rooms.recent.includes(:messages)

    render_json_response(
      status_code: 200,
      message: "Chat rooms",
      data: {
        rooms: Chat::RoomSerializer.new(rooms).serializable_hash[:data]
      }
    )
  end

  # POST /ai/rooms
  def create_room
    room = current_user.chat_rooms.create!(
      title: params[:title] || "New Conversation"
    )

    render_json_response(
      status_code: 201,
      message: "Room created",
      data: {
        room: Chat::RoomSerializer.new(room).serializable_hash[:data][:attributes]
      }
    )
  end

  # DELETE /ai/rooms/:id
  def destroy_room
    room = current_user.chat_rooms.find(params[:id])
    room.destroy

    render_json_response(
      status_code: 200,
      message: "Room deleted"
    )
  end

  # POST /ai/summarize
  def summarize
    text = params[:text]

    if text.blank?
      render_json_response(
        status_code: 422,
        message: "Text is required",
        error: "Missing text parameter"
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
        message: "AI service error",
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") || "No response"

      render_json_response(
        status_code: 200,
        message: "Summary generated",
        data: { summary: response_text }
      )
    end
  end

  # POST /ai/translate
  def translate
    text = params[:text]
    target_language = params[:target_language] || "English"

    if text.blank?
      render_json_response(
        status_code: 422,
        message: "Text is required",
        error: "Missing text parameter"
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
        message: "AI service error",
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") || "No response"

      render_json_response(
        status_code: 200,
        message: "Translation generated",
        data: { translation: response_text }
      )
    end
  end

  # POST /ai/analyze
  def analyze
    text = params[:text]
    analysis_type = params[:type] || "sentiment"

    if text.blank?
      render_json_response(
        status_code: 422,
        message: "Text is required",
        error: "Missing text parameter"
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
        message: "AI service error",
        error: result[:error]
      )
    else
      response_text = result.dig("choices", 0, "message", "content") || "No response"

      render_json_response(
        status_code: 200,
        message: "Analysis generated",
        data: { analysis: response_text }
      )
    end
  end

  private

  def set_room
    room_id = params[:room_id]

    if room_id.present?
      @room = current_user.chat_rooms.find(room_id)
    else
      @room = current_user.chat_rooms.first_or_create(
        title: "New Conversation"
      )
    end
  end

  def build_messages
    messages = []

    # System prompt (optional)
    if params[:system_prompt].present?
      messages << { role: "system", content: params[:system_prompt] }
    end

    # Get last 20 messages from room
    history = @room.messages.chronological.limit(20)

    history.each do |msg|
      messages << { role: msg.role, content: msg.content }
    end

    messages
  end
end
