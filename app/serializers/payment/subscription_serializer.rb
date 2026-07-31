class Payment::SubscriptionSerializer
  include JSONAPI::Serializer

  attributes :id, :stripe_subscription_id, :status, :payment_method_id, :cycle,
             :started_at, :next_billing_at, :ended_at, :canceled_at,
             :created_at, :updated_at, :user_id, :product_id

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer

  attribute :active do |subscription|
    subscription.active?
  end

  attribute :days_until_renewal do |subscription|
    subscription.days_until_renewal
  end

  attribute :product_name do |subscription|
    subscription.product&.name
  end

  attribute :price do |subscription|
    subscription.product&.display_price
  end

  attribute :period_label do |subscription|
    subscription.product&.period_label
  end
end
