FactoryBot.define do
  factory :payment_product, class: "Payment::Product" do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:stripe_product_id) { |n| "prod_#{n}" }
    sequence(:stripe_price_id) { |n| "price_#{n}" }
    price_unit_amount { 1_000 }
    currency { "usd" }
    cycle { "month" }
    active { true }
  end

  factory :payment_subscription, class: "Payment::Subscription" do
    user
    association :product, factory: :payment_product
    sequence(:stripe_subscription_id) { |n| "sub_#{n}" }
    stripe_customer_id { "cus_test" }
    status { "active" }
    cycle { "month" }
    current_period_start { Time.current }
    current_period_end { 30.days.from_now }
  end

  factory :payment_transaction, class: "Payment::Transaction" do
    user
    association :product, factory: :payment_product
    sequence(:stripe_payment_intent_id) { |n| "pi_#{n}" }
    status { "succeeded" }
    price_unit_amount { 1_000 }
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
end
