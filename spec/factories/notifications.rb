# spec/factories/notifications.rb

FactoryBot.define do
  factory :notification do
    user
    title { "Notification" }
    message { "You have a new notification." }
    event { "general_announcement" }
    data { { type: "general_announcement" } }

    trait :read do
      read_at { Time.current }
    end
  end
end
