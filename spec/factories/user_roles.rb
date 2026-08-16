FactoryBot.define do
  factory :user_role, class: "Iam::UserRole" do
    user
    role
  end
end
