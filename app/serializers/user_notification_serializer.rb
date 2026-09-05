# app/serializers/user_notification_serializer.rb

class UserNotificationSerializer < ApplicationSerializer
  attributes :id, :title, :message, :link, :data, :read_at, :created_at, :updated_at

  attribute :read do |record|
    record.read?
  end

  attribute :notification_id do |record|
    record.notification_id
  end
end
