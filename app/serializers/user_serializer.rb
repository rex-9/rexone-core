class UserSerializer
  include JSONAPI::Serializer
  attributes :id, :email, :username, :name, :provider, :bio, :created_at, :updated_at

  attribute :profile_pic_url do |user|
    user.get_profile_pic_url
  end
end
