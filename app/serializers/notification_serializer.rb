# app/serializers/notification_serializer.rb

class NotificationSerializer < ApplicationSerializer
  attributes :id,
             :title,
             :message,
             :event,
             :data,
             :read_at,
             :created_at,
             :updated_at

  attribute :read do |notification|
    notification.read?
  end
end
