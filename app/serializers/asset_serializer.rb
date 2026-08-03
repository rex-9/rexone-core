# app/serializers/asset_serializer.rb

class AssetSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :url, :category, :format, :extension, :size, :source, :created_at, :updated_at

  attribute :record_id do |asset|
    asset.record_id
  end

  attribute :record_type do |asset|
    asset.record_type
  end

  attribute :user_id do |asset|
    asset.user_id
  end

  belongs_to :user, serializer: UserSerializer, optional: true
end
