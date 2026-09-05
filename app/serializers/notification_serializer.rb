# app/serializers/notification_serializer.rb

class NotificationSerializer < ApplicationSerializer
  attributes :id,
             :event,
             :name,
             :description,
             :category,
             :link,
             :admin,
             :in_app_title,
             :in_app_body,
             :in_app_data,
             :push_title,
             :push_body,
             :push_template_id,
             :email_subject,
             :email_body,
             :email_template_id,
             :sent_count,
             :read_count,
             :discarded_at,
             :created_at,
             :updated_at
end
