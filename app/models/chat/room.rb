# app/models/chat/room.rb

module Chat
  class Room < ApplicationRecord
    self.table_name = "chat_rooms"

    belongs_to :user
    has_many :messages, class_name: "Chat::Message", dependent: :destroy

    validates :title, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :for_user, ->(user) { where(user: user) }

    def last_message
      messages.order(created_at: :desc).first
    end

    def message_count
      messages.count
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
