# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::RunSerializer do
  let(:user) { create(:user) }
  let(:run) do
    create(
      :ai_run,
      user: user,
      prompt_tokens: 1000,
      completion_tokens: 200,
      total_tokens: 1200,
      cost: 0.002646,
      status: AiConstants::RunStatus::COMPLETED
    )
  end

  it "serializes cost attribute as a float" do
    serialized = described_class.new(run).serializable_hash
    data = serialized[:data] || serialized

    expect(data[:attributes][:cost]).to eq(0.002646)
  end
end
