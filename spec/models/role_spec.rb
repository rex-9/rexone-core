require "rails_helper"

RSpec.describe Iam::Role, type: :model do
  it "requires a unique name" do
    create(:role, name: "admin")
    expect(build(:role, name: nil)).not_to be_valid
    expect(build(:role, name: "admin")).not_to be_valid
  end

  it "grants and revokes permissions idempotently" do
    role = create(:role, name: "editor")
    permission = create(:permission, action: "update", resource: "users")

    expect { 2.times { role.grant_permission(permission) } }.to change(role.permissions, :count).by(1)
    expect(role).to have_permission("update", "users")
    expect(role.can?("update", "users")).to be(true)

    expect { role.revoke_permission(permission) }.to change(role.permissions, :count).by(-1)
    expect(role).not_to have_permission("update", "users")
  end

  it "returns only system roles from the system scope" do
    system_role = create(:role, name: "user", system: true)
    create(:role, name: "custom", system: false)
    expect(described_class.system).to contain_exactly(system_role)
  end
end
