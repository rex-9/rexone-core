FactoryBot.define do
  factory :role, class: "Iam::Role" do
    name { "MyString" }
    description { "MyText" }
  end
end
