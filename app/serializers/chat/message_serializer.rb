# app/serializers/chat/message_serializer.rb:

class Chat::MessageSerializer < ApplicationSerializer
  attributes :id, :role, :content,  :audio_url, :metadata, :created_at, :updated_at

  attribute :room_id do |message|
    message.room_id
  end

  belongs_to :room, serializer: Chat::RoomSerializer
end
