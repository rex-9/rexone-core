class Payment::TransactionSerializer
  include JSONAPI::Serializer

  attributes :id, :stripe_payment_intent, :status, :payment_method_id,
             :price_unit_amount, :currency, :paid_at, :refunded_at,
             :created_at, :updated_at, :user_id, :product_id

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer, optional: true

  attribute :price_unit_amount do |transaction|
    transaction.display_price
  end

  attribute :paid do |transaction|
    transaction.paid?
  end

  attribute :refunded do |transaction|
    transaction.refunded?
  end

  attribute :product_name do |transaction|
    transaction.product&.name
  end
end
