# spec/factories/notifications.rb
FactoryBot.define do
  factory :notification do
    sequence(:event) { |n| "custom_event_#{n}" }
    sequence(:name) { |n| "Notification #{n}" }
    description { "Notification description" }
    category { NotificationConstants::Category::MARKETING }
    admin { false }
    in_app_title { "Hello {{user_name}}" }
    in_app_body { "Welcome to Rexone!" }
    push_title { "Hello {{user_name}}" }
    push_body { "Push body text" }
    email_subject { "Important update for {{user_name}}" }
    email_body { "<p>Email body text</p>" }

    trait :system do
      category { NotificationConstants::Category::SYSTEM }
      admin { false }
    end

    trait :broadcast do
      category { NotificationConstants::Category::BROADCAST }
      admin { true }
    end
  end

  factory :notification_template, parent: :notification

  factory :user_notification do
    user
    notification
    title { "Notification Title" }
    message { "Notification Message" }
    link { "/dashboard" }
    data { { "source" => "system" } }

    trait :read do
      read_at { Time.current }
    end

    trait :unread do
      read_at { nil }
    end
  end
end
