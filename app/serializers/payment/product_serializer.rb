class Payment::ProductSerializer < ApplicationSerializer
  attributes :id, :code, :name, :description, :price_unit_amount, :currency, :cycle,
             :stripe_product_id, :stripe_price_id, :active, :created_at, :updated_at,
             :discarded_at, :undiscarded_at

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
end
