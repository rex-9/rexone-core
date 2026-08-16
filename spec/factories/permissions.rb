FactoryBot.define do
  factory :permission, class: "Iam::Permission" do
    action { "read" }
    resource { "users" }
  end
end
