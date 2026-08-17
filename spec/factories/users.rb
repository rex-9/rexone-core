# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "user_#{n}" }
    name { "Test User" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }
    provider { "email" }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :google_provider do
      provider { "google" }
    end

    trait :super_admin do
      after(:create) do |user|
        role = Iam::Role.find_or_create_by(name: "super_admin")
        create(:user_role, user: user, role: role)
      end
    end

    trait :admin do
      after(:create) do |user|
        role = Iam::Role.find_or_create_by(name: "admin")
        create(:user_role, user: user, role: role)
      end
    end
  end
end
