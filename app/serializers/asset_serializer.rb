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
      thumbnail: asset.thumbnail ? AssetSerializer.child_payload(asset.thumbnail) : nil,
      subtitles: asset.subtitles.map { |subtitle| AssetSerializer.child_payload(subtitle) }
    }
  end

  belongs_to :creator, serializer: UserSerializer, id_method_name: :created_by_id, optional: true

  def self.child_payload(asset)
    {
      id: asset.id,
      name: asset.name,
      title: asset.title,
      description: asset.description,
      metadata: asset.metadata,
      url: asset.storage_url,
      type: asset.type,
      format: asset.format,
      extension: asset.extension,
      status: asset.status,
      size_bytes: asset.size_bytes,
      duration_secs: asset.duration_secs,
      parent_asset_id: asset.parent_asset_id,
      created_at: asset.created_at,
      updated_at: asset.updated_at
    }
  end
end
