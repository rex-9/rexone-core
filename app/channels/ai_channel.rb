# app/channels/ai_channel.rb
# Not Used Yet, useful in the future for AI streaming responses via WebSocket

class AiChannel < ApplicationCable::Channel
  def subscribed
    stream_from "user_#{current_user.id}_ai"
    transmit({
      type: "connected",
      message: "AI channel connected"
    })
  end

  def receive(data)
    message = data["message"]
    room_id = data["room_id"]
    history = data["history"] || []

    if message.blank?
      transmit({
        type: "error",
        error: "Message is required"
      })
      return
    end

    # Get or create room
    room = get_or_create_room(room_id)

    # Save user message
    room.messages.create!(
      role: "user",
      content: message
    )

    # Start streaming response
    stream_response(room, message, history)
  end

  private

  def get_or_create_room(room_id)
    if room_id.present?
      current_user.rooms.find(room_id)
    else
      current_user.rooms.first_or_create(
        title: "New Conversation"
      )
    end
  end

  def stream_response(room, message, history)
    messages = build_messages(room, history, message)
    full_response = ""

    # Send typing indicator
    transmit({ type: "typing", status: "started" })

    AiService::Client.stream_chat(
      messages: messages,
      temperature: 0.7,
      max_tokens: 2000
    ) do |chunk|
      if chunk.nil?
        # Stream ended - save the complete response
        if full_response.present?
          room.messages.create!(
            role: "assistant",
            content: full_response
          )

          # Update room title from first message if default
          room.update_title_from_first_message! if room.title == "New Conversation"
        end

        transmit({ type: "typing", status: "ended" })
      else
        full_response += chunk
        # Send chunk to client
        transmit({
          type: "chunk",
          content: chunk,
          room_id: room.id
        })
      end
    end
  rescue => e
    Rails.logger.error("[AI Channel] Error: #{e.message}")
    transmit({
      type: "error",
      error: e.message
    })
  end

  def build_messages(room, history, message)
    messages = []

    # Get last 20 messages from room
    room_history = room.messages.chronological.limit(20)

    # Add room history
    room_history.each do |msg|
      messages << { role: msg.role, content: msg.content }
    end

    # Add current message
    messages << { role: "user", content: message }

    messages
  end
end
