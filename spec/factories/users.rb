# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "user#{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
    jti { SecureRandom.uuid }
    confirmed_at { Time.current }
    provider { "email" }
    confirmation_token { SecureRandom.random_number(10**6).to_s.rjust(6, "0") }
    confirmation_sent_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :google_provider do
      provider { "google" }
      password { nil }
      password_confirmation { nil }
    end

    trait :locked do
      failed_attempts { 3 }
      locked_at { Time.current }
    end
  end
end