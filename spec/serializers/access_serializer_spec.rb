# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccessSerializer do
  let(:user) { create(:user, email: "access_test@example.com", username: "accessguy", name: "Access Guy") }
  let(:product) { create(:payment_product, name: "Premium Membership") }
  let(:access) do
    create(
      :access,
      user: user,
      product: product,
      status: "active",
      granted_at: Time.current,
      expires_at: 30.days.from_now
    )
  end

  it "serializes core access attributes and associated user and product data" do
    serialized = described_class.record_attributes(access)

    expect(serialized).to include(
      :id,
      :status,
      :granted_at,
      :expires_at,
      :revoked_at,
      :created_at,
      :updated_at,
      :product_id,
      :product_code,
      :product_name,
      :user_id,
      :user_email,
      :username,
      :user_name,
      :remaining_days,
      :active
    )

    expect(serialized[:id]).to eq(access.id)
    expect(serialized[:status]).to eq("active")
    expect(serialized[:product_id]).to eq(product.id)
    expect(serialized[:product_code]).to eq(product.code)
    expect(serialized[:product_name]).to eq("Premium Membership")
    expect(serialized[:user_id]).to eq(user.id)
    expect(serialized[:user_email]).to eq("access_test@example.com")
    expect(serialized[:username]).to eq("accessguy")
    expect(serialized[:user_name]).to eq("Access Guy")
    expect(serialized[:active]).to be(true)
    expect(serialized[:remaining_days]).to be_a(Integer)
  end

  it "handles lifetime access with nil expires_at" do
    lifetime_access = create(
      :access,
      user: user,
      product: product,
      status: "active",
      granted_at: Time.current,
      expires_at: nil
    )

    serialized = described_class.record_attributes(lifetime_access)

    expect(serialized[:expires_at]).to be_nil
    expect(serialized[:remaining_days]).to be_nil
    expect(serialized[:active]).to be(true)
  end

  it "reflects inactive status when access is revoked" do
    revoked_access = create(
      :access,
      user: user,
      product: product,
      status: "revoked",
      granted_at: 1.day.ago,
      revoked_at: Time.current,
      expires_at: 29.days.from_now
    )

    serialized = described_class.record_attributes(revoked_access)

    expect(serialized[:status]).to eq("revoked")
    expect(serialized[:active]).to be(false)
  end

  it "serializes collections of access records" do
    access1 = access
    product2 = create(:payment_product, name: "Second Product")
    access2 = create(:access, user: user, product: product2, status: "active", expires_at: nil)

    serialized_list = described_class.collection_attributes([ access1, access2 ])

    expect(serialized_list.length).to eq(2)
    expect(serialized_list.map { |a| a[:id] }).to contain_exactly(access1.id, access2.id)
  end

  it "handles nil record and empty collection gracefully" do
    expect(described_class.record_attributes(nil)).to be_nil
    expect(described_class.collection_attributes([])).to eq([])
  end
end
