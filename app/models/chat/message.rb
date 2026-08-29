# app/models/chat/message.rb
module Chat
  class Message < ApplicationRecord
    self.table_name = "chat_messages"

    AI_STATUSES = {
      queued: "queued",
      processing: "processing",
      retrying: "retrying",
      completed: "completed",
      failed: "failed"
    }.freeze
    AI_PROCESSING_STATUSES = AI_STATUSES.values_at(:queued, :processing, :retrying).freeze

    TTS_STATUSES = {
      queued: "queued",
      processing: "processing",
      retrying: "retrying",
      completed: "completed",
      failed: "failed"
    }.freeze

    store_accessor :metadata,
                   :status,
                   :system_prompt,
                   :temperature,
                   :max_tokens,
                   :assistant_message_id,
                   :error,
                   :usage,
                   :model,
                   prefix: :ai

    store_accessor :metadata, :tts_status, :tts_error

    belongs_to :room, class_name: "Chat::Room"
    has_many :assets,
             -> { where("LOWER(resource_model) = 'chat_message'") },
             foreign_key: :resource_id,
             dependent: :nullify

    validates :role, presence: true, inclusion: { in: %w[user assistant] }
    validates :content, presence: true

    scope :chronological, -> { order(created_at: :asc) }
    scope :recent, -> { order(created_at: :desc).limit(20) }
    scope :user_messages, -> { where(role: AiConstants::ChatRole::USER) }
    scope :ai_processing, -> {
      where(role: AiConstants::ChatRole::USER)
        .where("metadata ->> 'status' IN (?)", AI_PROCESSING_STATUSES)
    }

    def user?
      role == AiConstants::ChatRole::USER
    end

    def assistant?
      role == AiConstants::ChatRole::ASSISTANT
    end

    def ai_processing?
      user? && ai_status.in?(AI_PROCESSING_STATUSES)
    end

    def tts_asset
      assets.find_or_initialize_by(
        type: AssetConstants::AssetType::AUDIO,
        source: AssetConstants::AssetSource::UPLOAD
      )
    end
  end
end
