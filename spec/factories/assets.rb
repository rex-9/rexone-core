require 'faker'

FactoryBot.define do
  factory :asset do
    sequence(:name) { |n| "google_profile_picture_#{n}" }
    url { |n| "https://res.cloudinary.com/meritbox/image/upload/v1733153191/cld-sample-#{n}.jpg" }
    category { %w[profile banner merit wish thank].sample }
    format { 'image' }
    size { rand(1000..5000) } # Random size between 1000 and 5000 bytes
    source { %w[google upload].sample }
    association :user

    before(:create) do |asset|
      asset.extension = File.extname(URI.parse(asset.url).path).delete(".")
    end
  end
end
