require "rails_helper"

RSpec.describe Iam::RolePermission, type: :model do
  it "requires both role and permission" do
    expect(build(:role_permission)).to be_valid
    expect(build(:role_permission, role: nil)).not_to be_valid
    expect(build(:role_permission, permission: nil)).not_to be_valid
  end

  it "prevents assigning the same permission to a role twice" do
    assignment = create(:role_permission)
    duplicate = build(:role_permission, role: assignment.role, permission: assignment.permission)
    expect(duplicate).not_to be_valid
  end

  it "is removed when either parent is destroyed" do
    assignment = create(:role_permission)
    expect { assignment.role.destroy! }.to change(described_class, :count).by(-1)
  end
end
