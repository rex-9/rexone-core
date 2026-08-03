# app/serializers/iam/permission_serializer.rb:

module Iam
  class PermissionSerializer
    include JSONAPI::Serializer

    attributes :id, :name, :action, :resource, :created_at, :updated_at
  end
end
