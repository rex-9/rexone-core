# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ProfileService do
  describe ".resolve!" do
    it "resolves default chat profile from seeds or creates it" do
      profile = described_class.resolve!(AiConstants::ProfileKey::CHAT)
      expect(profile).to be_persisted
      expect(profile.key).to eq(AiConstants::ProfileKey::CHAT)
      expect(profile.provider).to eq(AiConstants::Provider::DEEPSEEK)
      expect(profile.enabled?).to be(true)
    end

    it "raises error if profile is disabled" do
      profile = described_class.resolve!(AiConstants::ProfileKey::CHAT)
      profile.update!(enabled: false)

      expect {
        described_class.resolve!(AiConstants::ProfileKey::CHAT)
      }.to raise_error(Ai::ProfileService::Error, /disabled/)
    end

    it "marks profile as disabled when discarded and raises disabled error" do
      profile = create(:ai_profile, key: "custom_agent", name: "Custom Agent", enabled: true)
      profile.discard!

      expect(profile.enabled).to be(false)
      expect(profile.enabled?).to be(false)
      expect {
        described_class.resolve!("custom_agent")
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
    let!(:profile) { described_class.resolve!(AiConstants::ProfileKey::CHAT) }

    it "updates profile configuration" do
      described_class.update!(profile, temperature: 0.9, max_output_tokens: 3000)
      expect(profile.reload.temperature).to eq(0.9)
      expect(profile.max_output_tokens).to eq(3000)
    end

    it "registers new custom model and pricing in ai_prices database table and auto-calculates cached rate when omitted" do
      described_class.update!(
        profile,
        provider: "gemini",
        model: "gemini-3.0-pro-preview",
        input_cost_per_million: 1.50,
        output_cost_per_million: 6.00
      )

      expect(profile.reload.provider).to eq("gemini")
      expect(profile.model).to eq("gemini-3.0-pro-preview")

      price = Ai::Price.kept.find_by(provider: "gemini", model: "gemini-3.0-pro-preview")
      expect(price).to be_present
      expect(price.input_cost_per_million.to_f).to eq(1.50)
      expect(price.cached_cost_per_million.to_f).to eq(0.75)
      expect(price.output_cost_per_million.to_f).to eq(6.00)

      gemini_provider = described_class.config[:providers].find { |p| p[:key] == "gemini" }
      model_entry = gemini_provider[:models].find { |m| m[:model] == "gemini-3.0-pro-preview" }
      expect(model_entry).to include(
        input_cost_per_million: 1.50,
        cached_cost_per_million: 0.75,
        output_cost_per_million: 6.00
      )
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

  describe ".sync_prices!" do
    it "syncs upstream pricing catalog" do
      allow(Ai::PriceSyncService).to receive(:sync!).and_return(12)

      expect(described_class.sync_prices!).to eq(12)
      expect(Ai::PriceSyncService).to have_received(:sync!)
    end
  end
end
