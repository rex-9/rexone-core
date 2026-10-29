# frozen_string_literal: true

# app/models/chat/message/metadata.rb
# Deterministic metadata contract for Chat::Message AI executions, chunking, and TTS states.
module Chat
  class Message
    class Metadata < ApplicationMetadata
      # AI generation status ('pending', 'processing', 'completed', 'failed').
      attribute :status, :string

      # System prompt configuration instructing the AI model for this turn.
      attribute :system_prompt, :string

      # Sampling temperature parameter controlling randomness/creativity (e.g. 0.7).
      attribute :temperature, :float

      # Maximum token output ceiling configured for the generation request.
      attribute :max_tokens, :integer

      # UUID of the complementary assistant response message.
      attribute :assistant_message_id, :string

      # Error details if the generation failed.
      attribute :error, :string

      # Token usage statistics from provider (prompt_tokens, completion_tokens, total_tokens).
      attribute :usage, default: -> { {} }

      # Specific model identifier used for inference (e.g. "gemini-2.5-flash", "gpt-4o").
      attribute :model, :string

      # Text-to-speech generation state ('pending', 'processing', 'ready', 'failed').
      attribute :tts_status, :string

      # Error details if text-to-speech audio synthesis failed.
      attribute :tts_error, :string

      # Zero-based index of this chunk when a message was partitioned across multiple blocks.
      attribute :chunk_index, :integer

      # Total number of chunks this message was split into.
      attribute :total_chunks, :integer

      # Unique correlation identifier binding all split chunks together.
      attribute :split_id, :string

      validates :status, inclusion: { in: AiConstants::ChatStatus::ALL }, allow_nil: true
      validates :chunk_index, :total_chunks, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    end
  end
end
