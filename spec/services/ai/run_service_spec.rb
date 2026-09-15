# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::RunService do
  let(:user) { create(:user) }
  let!(:profile) { Ai::ProfileService.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT) }

  describe ".execute_chat" do
    it "records an Ai::Run and updates telemetry on completion" do
      fake_response = {
        "id" => "run-123",
        "choices" => [ { "message" => { "content" => "Hello from AI!" } } ],
        "usage" => { "prompt_tokens" => 15, "completion_tokens" => 8, "total_tokens" => 23 }
      }
      allow(Ai::Providers::Client).to receive(:chat).and_return(fake_response)

      result = described_class.execute_chat(
        user: user,
        feature: AiConstants::RunFeature::CHAT,
        profile_key: profile.key,
        messages: [ { role: "user", content: "Hi" } ]
      )

      expect(result).to eq(fake_response)

      run = Ai::Run.last
      expect(run.user).to eq(user)
      expect(run.profile).to eq(profile)
      expect(run.status).to eq(AiConstants::RunStatus::COMPLETED)
      expect(run.output_chars).to eq("Hello from AI!".length)
      expect(run.prompt_tokens).to eq(15)
      expect(run.completion_tokens).to eq(8)
      expect(run.total_tokens).to eq(23)
      expect(run.latency_ms).to be >= 0
    end

    it "records failure telemetry when LLM returns error" do
      allow(Ai::Providers::Client).to receive(:chat).and_return({ error: "API rate limit exceeded" })

      described_class.execute_chat(
        user: user,
        feature: AiConstants::RunFeature::CHAT,
        profile_key: profile.key,
        messages: [ { role: "user", content: "Hi" } ]
      )

      run = Ai::Run.last
      expect(run.status).to eq(AiConstants::RunStatus::FAILED)
      expect(run.error).to eq("API rate limit exceeded")
    end
  end

  describe ".list" do
    it "filters runs by feature, status, and user" do
      run1 = create(:ai_run, user: user, feature: AiConstants::RunFeature::CHAT, status: AiConstants::RunStatus::COMPLETED)
      run2 = create(:ai_run, user: user, feature: AiConstants::RunFeature::SUMMARIZE, status: AiConstants::RunStatus::FAILED)

      expect(described_class.list(feature: AiConstants::RunFeature::CHAT)).to include(run1)
      expect(described_class.list(feature: AiConstants::RunFeature::CHAT)).not_to include(run2)
      expect(described_class.list(status: AiConstants::RunStatus::FAILED)).to include(run2)
    end
  end
end
