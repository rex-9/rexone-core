# app/models/chat/message.rb
module Chat
  class Message < ApplicationRecord
    self.table_name = "chat_messages"

    belongs_to :room, class_name: "Chat::Room"

    validates :role, presence: true, inclusion: { in: %w[user assistant] }
    validates :content, presence: true

    scope :chronological, -> { order(created_at: :asc) }
    scope :recent, -> { order(created_at: :desc).limit(20) }

    def user?
      role == "user"
    end

    def assistant?
      role == "assistant"
    end
  end
end
