# app/serializers/iam/user_role_serializer.rb

module Iam
  class UserRoleSerializer
    include JSONAPI::Serializer

    attributes :id, :created_at, :updated_at

    belongs_to :user, serializer: UserSerializer
    belongs_to :role, serializer: Iam::RoleSerializer
  end
end
