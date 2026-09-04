# app/serializers/asset_serializer.rb

class AssetSerializer < ApplicationSerializer
  attributes :id, :name, :type, :format, :extension, :size_bytes, :duration_secs, :source, :status, :assetable_type, :assetable_id, :created_at, :updated_at

  attribute :url do |asset|
    asset.storage_url
  end

  belongs_to :creator, serializer: UserSerializer, id_method_name: :created_by_id, optional: true
end
