# frozen_string_literal: true

# app/models/chat/room/metadata.rb
# Deterministic metadata contract for Chat::Room sessions.
module Chat
  class Room
    class Metadata < ApplicationMetadata
      # AI-summarized topic or main theme of the conversation thread.
      attribute :topic, :string

      # Rolling contextual summary used for memory injection into new AI model turns.
      attribute :context_summary, :string
    end
  end
end
