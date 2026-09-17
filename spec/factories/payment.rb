FactoryBot.define do
  factory :payment_product, class: "Payment::Product" do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:stripe_product_id) { |n| "prod_#{n}" }
    sequence(:stripe_price_id) { |n| "price_#{n}" }
    unit_amount { 1_000 }
    currency { "usd" }
    interval { "month" }
    active { true }
  end

  factory :payment_subscription, class: "Payment::Subscription" do
    user
    association :product, factory: :payment_product
    sequence(:stripe_subscription_id) { |n| "sub_#{n}" }
    sequence(:stripe_subscription_item_id) { |n| "si_#{n}" }
    sequence(:stripe_price_id) { |n| "price_subscription_#{n}" }
    stripe_customer_id { "cus_test" }
    status { "active" }
    currency { "usd" }
    unit_amount { 1_000 }
    quantity { 1 }
    interval { "month" }
    interval_count { 1 }
    current_period_start { Time.current }
    current_period_end { 30.days.from_now }
    started_at { Time.current }
  end

  factory :payment_transaction, class: "Payment::Transaction" do
    user
    association :product, factory: :payment_product
    sequence(:stripe_payment_intent_id) { |n| "pi_#{n}" }
    status { "succeeded" }
    unit_amount { 1_000 }
    currency { "usd" }
  end

  factory :access do
    user
    association :product, factory: :payment_product
    status { "active" }
    granted_at { Time.current }
    expires_at { 30.days.from_now }
  end

  factory :payment_webhook_event, class: "Payment::WebhookEvent" do
    sequence(:stripe_event_id) { |n| "evt_#{n}" }
    event_type { "checkout.session.completed" }
    status { "pending" }
    payload { { "id" => stripe_event_id, "type" => event_type, "data" => { "object" => {} } } }
    received_at { Time.current }
  end

  factory :payment_coupon, class: "Payment::Coupon" do
    sequence(:title) { |n| "Coupon #{n}" }
    sequence(:code) { |n| "COUPON#{n}" }
    coupon_type { :percentage }
    amount { 20 }
    currency { "usd" }
    max_usage { 100 }
    max_usage_per_user { 1 }
    used_count { 0 }
    expires_at { 30.days.from_now }
    active { true }
  end

  factory :payment_user_coupon, class: "Payment::UserCoupon" do
    association :coupon, factory: :payment_coupon
    user
    association :product, factory: :payment_product
    purchase_id { SecureRandom.uuid }
    purchase_type { :trx }
    discount_amount { 200 }
    original_amount { 1_000 }
    final_amount { 800 }
    currency { "usd" }
  end
end
