# app/serializers/chat/room_serializer.rb

class Chat::RoomSerializer < ApplicationSerializer
  attributes :id, :title, :metadata, :created_at, :updated_at

  attribute :user_id do |room|
    room.user_id
  end

  attribute :message_count do |room|
    room.messages.count
  end

  attribute :last_message do |room|
    room.messages.last&.content
  end

  belongs_to :user, serializer: UserSerializer
  has_many :messages, serializer: Chat::MessageSerializer
end
