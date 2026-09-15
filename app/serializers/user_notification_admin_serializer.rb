# frozen_string_literal: true

# app/serializers/user_notification_admin_serializer.rb
class UserNotificationAdminSerializer < ApplicationSerializer
  set_type :user_notification

  attributes :id, :title, :message, :link, :clients, :metadata, :operation_id,
             :operation_type, :operation_status,
             :read_at, :discarded_at, :created_at, :updated_at

  attribute :read do |record|
    record.read?
  end

  attribute :user_id do |record|
    record.user_id
  end

  attribute :user_email do |record|
    record.user&.email
  end

  attribute :user_name do |record|
    record.user&.name || record.user&.username
  end

  attribute :notification_id do |record|
    record.notification_id
  end

  attribute :notification_event do |record|
    record.notification&.event
  end
end
