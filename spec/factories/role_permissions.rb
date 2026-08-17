FactoryBot.define do
  factory :role_permission, class: "Iam::RolePermission" do
    role
    permission
  end
end
