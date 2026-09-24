# app/serializers/user_serializer.rb:

class UserSerializer < ApplicationSerializer
  attributes :id, :email, :username, :name, :provider, :confirmed_at,
             :created_at, :updated_at, :discarded_at, :undiscarded_at

  attribute :confirmed do |user|
    user.confirmed?
  end

  attribute :avatar_url do |user|
    user.get_avatar_url
  end

  attribute :avatar_asset_id do |user|
    user.assets.find_by(type: AssetConstants::AssetType::AVATAR)&.id
  end

  attribute :iam do |user|
    {
      is_admin: user.admin?,
      is_super_admin: user.super_admin?,
      roles: Iam::RoleSerializer.new(user.roles).serializable_hash[:data],
      admin_roles: Iam::RoleSerializer.new(user.admin_roles).serializable_hash[:data],
      non_admin_roles: Iam::RoleSerializer.new(user.non_admin_roles).serializable_hash[:data],
      permissions: Iam::PermissionSerializer.new(user.permissions).serializable_hash[:data],
      admin_permissions: Iam::PermissionSerializer.new(user.admin_permissions).serializable_hash[:data],
      non_admin_permissions: Iam::PermissionSerializer.new(user.non_admin_permissions).serializable_hash[:data]
    }
  end
end
