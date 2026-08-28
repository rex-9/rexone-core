# app/serializers/feedback_serializer.rb

class FeedbackSerializer < ApplicationSerializer
  attributes :id,
             :content,
             :rating,
             :category,
             :priority,
             :status,
             :platform,
             :app_version,
             :os,
             :device,
             :browser,
             :page,
             :metadata,
             :admin_notes,
             :created_at,
             :updated_at

  attribute :user_id do |feedback|
    feedback.user_id
  end

  attribute :user_name do |feedback|
    feedback.user&.name
  end

  attribute :user_email do |feedback|
    feedback.user&.email
  end
end
