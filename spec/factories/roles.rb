FactoryBot.define do
  factory :role, class: "Iam::Role" do
    sequence(:name) { |n| "role_#{n}" }
    description { "MyText" }
  end
end
