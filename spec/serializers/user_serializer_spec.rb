# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSerializer do
  let(:user) { create(:user) }
  let(:product) { create(:payment_product, name: "AI Pro", code: "AIPRO12345") }

  it "serializes core attributes, iam, and active accesses" do
    AccessService.grant(user_id: user.id, product_id: product.id)

    serialized = described_class.new(user).serializable_hash[:data][:attributes]

    expect(serialized).to include(:id, :email, :username, :name, :iam, :accesses)
    expect(serialized[:iam]).to be_a(Hash)
    expect(serialized[:accesses]).to be_an(Array)
    expect(serialized[:accesses].size).to eq(1)

    first_access = serialized[:accesses].first
    expect(first_access[:product_id]).to eq(product.id)
    expect(first_access[:product_code]).to eq(product.code)
    expect(first_access[:product_name]).to eq("AI Pro")
    expect(first_access[:active]).to be(true)
    expect(first_access[:status]).to eq("active")
    expect(first_access).to include(:granted_at, :expires_at, :remaining_days, :created_at, :updated_at)
  end
end
