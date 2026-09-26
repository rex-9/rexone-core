# app/serializers/asset_serializer.rb

class AssetSerializer < ApplicationSerializer
  attributes :id, :name, :title, :description, :metadata, :type, :format, :extension, :size_bytes, :duration_secs, :source, :status, :assetable_type, :assetable_id, :parent_asset_id, :created_at, :updated_at

  attribute :url do |asset|
    asset.storage_url
  end

  attribute :display_name do |asset|
    asset.display_name
  end

  attribute :children do |asset|
    {
      thumbnail: AssetSerializer.record_attributes(asset.thumbnail),
      subtitles: AssetSerializer.collection_attributes(asset.subtitles)
    }
  end

  belongs_to :creator, serializer: UserSerializer, id_method_name: :created_by_id, optional: true
end
