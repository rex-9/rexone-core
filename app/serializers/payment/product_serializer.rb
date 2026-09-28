class Payment::ProductSerializer < ApplicationSerializer
  attributes :id, :code, :name, :description, :unit_amount, :currency, :interval,
             :stripe_product_id, :stripe_price_id, :google_play_product_id, :app_store_product_id,
             :active, :created_at, :updated_at, :discarded_at, :undiscarded_at

  attribute :price do |product|
    product.display_price
  end

  attribute :period_label do |product|
    product.period_label
  end

  attribute :recurring do |product|
    product.recurring?
  end

  attribute :free do |product|
    product.free?
  end

  attribute :in_app do |product|
    product.in_app?
  end

  attribute :supported_providers do |product|
    product.supported_providers
  end

  attribute :thumbnail_url do |product|
    product.get_thumbnail_url
  end

  attribute :thumbnail_asset_id do |product|
    product.assets.find_by(type: AssetConstants::AssetType::THUMBNAIL)&.id
  end
end
