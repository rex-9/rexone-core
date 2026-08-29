# app/serializers/iam/role_serializer.rb:

class Iam::RoleSerializer < ApplicationSerializer
  attributes :id, :name, :description, :system, :created_at, :updated_at

  attribute :admin do |role|
    role.admin?
  end

  attribute :permissions do |role|
    role.permissions.group_by(&:resource).transform_values { |p| p.pluck(:action) }
  end

  attribute :permission_ids do |role|
    role.permissions.pluck(:id)
  end

  attribute :user_count do |role|
    role.users.count
  end
end
