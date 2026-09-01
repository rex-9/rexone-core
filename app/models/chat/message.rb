# app/models/chat/message.rb
module Chat
  class Message < ApplicationRecord
    self.table_name = "chat_messages"

    STATUSES = {
      queued: AiConstants::ChatStatus::QUEUED,
      processing: AiConstants::ChatStatus::PROCESSING,
      retrying: AiConstants::ChatStatus::RETRYING,
      completed: AiConstants::ChatStatus::COMPLETED,
      failed: AiConstants::ChatStatus::FAILED
    }.freeze
    PROCESSING_STATUSES = AiConstants::ChatStatus::PROCESSING_SET

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

    validates :role, presence: true, inclusion: { in: [ AiConstants::ChatRole::USER, AiConstants::ChatRole::ASSISTANT ] }
    validates :content, presence: true

    scope :chronological, -> { order(created_at: :asc) }
    scope :recent, -> { order(created_at: :desc).limit(20) }
    scope :user_messages, -> { where(role: AiConstants::ChatRole::USER) }
    scope :ai_processing, -> {
      where(role: AiConstants::ChatRole::USER)
        .where("metadata ->> 'status' IN (?)", PROCESSING_STATUSES)
    }

    def user?
      role == AiConstants::ChatRole::USER
    end

    def assistant?
      role == AiConstants::ChatRole::ASSISTANT
    end

    def ai_processing?
      user? && ai_status.in?(PROCESSING_STATUSES)
    end

    def tts_asset
      assets.find_or_initialize_by(
        type: AssetConstants::AssetType::AUDIO,
        source: AssetConstants::AssetSource::UPLOAD
      )
    end
  end
end
