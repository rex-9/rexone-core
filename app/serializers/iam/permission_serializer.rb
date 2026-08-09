# app/serializers/iam/permission_serializer.rb:

class Iam::PermissionSerializer < ApplicationSerializer
  attributes :id, :name, :action, :resource, :created_at, :updated_at
end
