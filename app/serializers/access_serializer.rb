# app/serializers/access_serializer.rb

class AccessSerializer < ApplicationSerializer
  attributes :id, :status, :granted_at, :expires_at, :revoked_at, :created_at, :updated_at

  attribute :product_id do |access|
    access.product_id
  end

  attribute :product_code do |access|
    access.product&.code
  end

  attribute :product_name do |access|
    access.product&.name
  end

  attribute :user_id do |access|
    access.user_id
  end

  attribute :user_email do |access|
    access.user&.email
  end

  attribute :username do |access|
    access.user&.username
  end

  attribute :user_name do |access|
    access.user&.name
  end

  attribute :remaining_days do |access|
    access.remaining_days
  end

  attribute :active do |access|
    access.active?
  end

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer, optional: true
end
