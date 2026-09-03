# app/serializers/asset_serializer.rb

class AssetSerializer < ApplicationSerializer
  attributes :id, :name, :url, :type, :format, :extension, :size_bytes, :duration_secs, :source, :assetable_type, :assetable_id, :created_by_id, :created_at, :updated_at

  belongs_to :creator, serializer: UserSerializer, id_method_name: :created_by_id, optional: true
end
