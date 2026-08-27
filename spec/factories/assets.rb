require "faker"

FactoryBot.define do
  factory :asset do
    sequence(:name) { |n| "asset_file_#{n}" }
    sequence(:url) { |n| "https://example.com/asset_#{n}.jpg" }
    type { "avatar" }
    format { "image" }
    size_bytes { 1024 }
    duration_secs { nil }
    source { "upload" }
    sequence(:storage_key) { |n| "avatar/asset_file_#{n}" }
    association :creator, factory: :user
    resource_model { "user" }
    resource_id { creator&.id || SecureRandom.uuid }
  end
end
