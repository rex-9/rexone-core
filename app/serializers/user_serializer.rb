# app/serializers/user_serializer.rb:

class UserSerializer < ApplicationSerializer
  attributes :id, :email, :username, :name, :provider, :created_at, :updated_at, :discarded_at, :undiscarded_at

  attribute :avatar_url do |user|
    user.get_avatar_url
  end

  attribute :avatar_asset_id do |user|
    user.assets.find_by(type: AssetConstants::AssetType::AVATAR)&.id
  end

  attribute :role_ids do |user|
    user.roles.pluck(:id)
  end

  attribute :role_names do |user|
    user.roles.pluck(:name)
  end

  attribute :permissions do |user|
    user.permissions.group_by(&:resource).transform_values { |p| p.pluck(:action) }
  end
end
