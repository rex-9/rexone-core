# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ProfileService do
  describe ".resolve!" do
    it "resolves default chat profile from seeds or creates it" do
      profile = described_class.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT)
      expect(profile).to be_persisted
      expect(profile.key).to eq(AiConstants::ProfileKey::CHAT_DEFAULT)
      expect(profile.provider).to eq(AiConstants::Provider::DEEPSEEK)
      expect(profile.enabled?).to be(true)
    end

    it "raises error if profile is disabled" do
      profile = described_class.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT)
      profile.update!(enabled: false)

      expect {
        described_class.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT)
      }.to raise_error(Ai::ProfileService::Error, /disabled/)
    end

    it "raises error for invalid profile key" do
      expect {
        described_class.resolve!("unknown_key")
      }.to raise_error(Ai::ProfileService::Error, /Unknown AI profile/)
    end
  end

  describe ".find" do
    let!(:profile) { described_class.resolve!(AiConstants::ProfileKey::SUMMARIZE) }

    it "finds by UUID" do
      expect(described_class.find(profile.id)).to eq(profile)
    end

    it "finds by key string" do
      expect(described_class.find(AiConstants::ProfileKey::SUMMARIZE)).to eq(profile)
    end
  end

  describe ".update!" do
    let!(:profile) { described_class.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT) }

    it "updates profile configuration" do
      described_class.update!(profile, temperature: 0.9, max_output_tokens: 3000)
      expect(profile.reload.temperature).to eq(0.9)
      expect(profile.max_output_tokens).to eq(3000)
    end
  end

  describe ".prompt_for" do
    let!(:profile) { described_class.resolve!(AiConstants::ProfileKey::TRANSLATE) }

    it "interpolates prompt variables" do
      prompt = described_class.prompt_for(profile, language: "Burmese")
      expect(prompt).to include("Burmese")
    end

    it "automatically encodes structured array or hash variables into TOON" do
      custom_profile = create(:ai_profile, system_prompt: "Here is the data context:\n%{context}\nPlease analyze it.")
      users = [
        { id: 1, name: "Alice", role: "admin" },
        { id: 2, name: "Bob", role: "member" }
      ]

      result = described_class.prompt_for(custom_profile, context: users)
      expect(result).to include("[2]{id,name,role}:")
      expect(result).to include("  1,Alice,admin")
      expect(result).to include("  2,Bob,member")
    end
  end
end
