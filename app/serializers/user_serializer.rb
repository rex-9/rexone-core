class UserSerializer
  include JSONAPI::Serializer
  attributes :id, :email, :username, :name, :provider, :photo, :created_at, :updated_at
end
