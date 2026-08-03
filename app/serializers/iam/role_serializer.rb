# app/serializers/iam/role_serializer.rb:

module Iam
  class RoleSerializer
    include JSONAPI::Serializer

    attributes :id, :name, :description, :system, :created_at, :updated_at

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
end
