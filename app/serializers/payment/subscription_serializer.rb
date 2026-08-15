# app/serializers/payment/subscription_serializer.rb
class Payment::SubscriptionSerializer < ApplicationSerializer
  attributes :id,
            :stripe_subscription_id,
            :stripe_customer_id,
            :status,
            :cycle,
            :payment_method_id,
            :payment_method_type,
            :current_period_start,
            :current_period_end,
            :started_at,
            :ended_at,
            :canceled_at,
            :cancel_at,
            :cancel_at_period_end,
            :created_at,
            :updated_at,
            :user_id,
            :product_id

  belongs_to :user, serializer: UserSerializer
  belongs_to :product, serializer: Payment::ProductSerializer

  # Status helpers
  attribute :active do |subscription|
    subscription.active?
  end

  attribute :canceled do |subscription|
    subscription.canceled?
  end

  attribute :past_due do |subscription|
    subscription.past_due?
  end

  attribute :ended do |subscription|
    subscription.ended?
  end

  attribute :expired do |subscription|
    subscription.expired?
  end

  attribute :scheduled_for_cancellation do |subscription|
    subscription.scheduled_for_cancellation?
  end

  attribute :cancelable do |subscription|
    subscription.cancelable?
  end

  # Days until renewal
  attribute :renewing do |subscription|
    subscription.renewing?
  end

  attribute :days_until_renewal do |subscription|
    subscription.days_until_renewal
  end

  attribute :days_until_period_end do |subscription|
    subscription.days_until_period_end
  end
  # Payment method display
  attribute :payment_method_display do |subscription|
    subscription.payment_method_display
  end

  attribute :card_last4 do |subscription|
    subscription.card_last4
  end

  attribute :card_brand do |subscription|
    subscription.card_brand
  end

  attribute :masked_card_number do |subscription|
    subscription.masked_card_number
  end

  # Product details
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
