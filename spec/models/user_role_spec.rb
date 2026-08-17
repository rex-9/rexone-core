require "rails_helper"

RSpec.describe Iam::UserRole, type: :model do
  it "requires a user and role" do
    expect(build(:user_role)).to be_valid
    expect(build(:user_role, user: nil)).not_to be_valid
    expect(build(:user_role, role: nil)).not_to be_valid
  end

  it "prevents assigning the same role to a user twice" do
    assignment = create(:user_role)
    duplicate = build(:user_role, user: assignment.user, role: assignment.role)
    expect(duplicate).not_to be_valid
  end

  it "is removed when its user or role is destroyed" do
    assignment = create(:user_role)
    expect { assignment.user.destroy! }.to change(described_class, :count).by(-1)
  end
end
