require "rails_helper"

RSpec.describe Iam::Permission, type: :model do
  it "builds its canonical name from action and resource" do
    permission = described_class.create!(action: "read", resource: "users")
    expect(permission.name).to eq("read_users")
  end

  it "accepts every declared action and resource" do
    described_class::ACTIONS.each do |action|
      described_class::RESOURCES.each do |resource|
        expect(build(:permission, action: action, resource: resource)).to be_valid
      end
    end
  end

  it "rejects unsupported or missing actions and resources" do
    expect(build(:permission, action: "approve", resource: "users")).not_to be_valid
    expect(build(:permission, action: "read", resource: "unknown")).not_to be_valid
    expect(build(:permission, action: nil, resource: "users")).not_to be_valid
  end

  it "prevents duplicate action-resource permissions through the generated name" do
    create(:permission, action: "read", resource: "users")
    expect(build(:permission, action: "read", resource: "users")).not_to be_valid
  end

  it "filters permissions by action and resource" do
    read_users = create(:permission, action: "read", resource: "users")
    create(:permission, action: "delete", resource: "users")
    create(:permission, action: "read", resource: "assets")

    expect(described_class.for_action("read").for_resource("users")).to contain_exactly(read_users)
  end
end
