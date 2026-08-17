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

    store_accessor :metadata,
                   :status,
                   :notification_locale,
                   :system_prompt,
                   :temperature,
                   :max_tokens,
                   :assistant_message_id,
                   :error,
                   :usage,
                   :model,
                   prefix: :ai

    belongs_to :room, class_name: "Chat::Room"

    validates :role, presence: true, inclusion: { in: %w[user assistant] }
    validates :content, presence: true

    scope :chronological, -> { order(created_at: :asc) }
    scope :recent, -> { order(created_at: :desc).limit(20) }
    scope :ai_processing, -> {
      where(role: "user")
        .where("metadata ->> 'status' IN (?)", AI_PROCESSING_STATUSES)
    }

    def user?
      role == "user"
    end

    def assistant?
      role == "assistant"
    end

    def ai_processing?
      user? && ai_status.in?(AI_PROCESSING_STATUSES)
    end
  end
end
