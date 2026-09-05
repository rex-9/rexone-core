# app/models/chat/room.rb

module Chat
  class Room < ApplicationRecord
    self.table_name = "chat_rooms"

    belongs_to :user
    has_many :messages, class_name: "Chat::Message", dependent: :destroy

    validates :title, presence: true

    scope :recent, -> { order(SortConstants::Columns::CHAT_ROOM.first => SortConstants::Order::DESC) }
    scope :for_user, ->(user) { where(user: user) }

    def last_message
      messages.order(SortConstants::Columns::CHAT_MSG.first => SortConstants::Order::DESC).first
    end

    def message_count
      messages.count
    end

    def processing?
      messages.ai_processing.exists?
    end

    def update_title_from_first_message!
      return if messages.empty?
      first_message = messages.order(:created_at).first
      return unless first_message.user?

      # Truncate first user message as title
      new_title = first_message.content.truncate(50)
      update(title: new_title)
    end
  end
end
