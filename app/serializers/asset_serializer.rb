# app/serializers/asset_serializer.rb

class AssetSerializer < ApplicationSerializer
  attributes :id, :name, :type, :format, :extension, :size_bytes, :duration_secs, :source, :status, :assetable_type, :assetable_id, :parent_asset_id, :created_at, :updated_at

  attribute :url do |asset|
    asset.storage_url
  end

  attribute :thumbnail do |asset|
    thumbnail = asset.thumbnail
    next unless thumbnail

    {
      id: thumbnail.id,
      url: thumbnail.storage_url,
      status: thumbnail.status,
      size_bytes: thumbnail.size_bytes
    }
  end

  attribute :subtitle do |asset|
    subtitle = asset.subtitle
    next unless subtitle

    {
      id: subtitle.id,
      url: subtitle.storage_url,
      status: subtitle.status,
      size_bytes: subtitle.size_bytes
    }
  end

  belongs_to :creator, serializer: UserSerializer, id_method_name: :created_by_id, optional: true
end
