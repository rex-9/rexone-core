# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::PriceSyncService do
  describe ".sync!" do
    let(:sample_registry_payload) do
      {
        "deepseek/deepseek-chat" => {
          "litellm_provider" => "deepseek",
          "input_cost_per_token" => 0.00000014,
          "cache_read_input_token_cost" => 0.000000014,
          "output_cost_per_token" => 0.00000028
        },
        "gemini/gemini-2.5-flash" => {
          "litellm_provider" => "gemini",
          "input_cost_per_token" => 0.00000015,
          "output_cost_per_token" => 0.00000060
        },
        "untracked-vendor/some-model" => {
          "litellm_provider" => "untracked-vendor",
          "input_cost_per_token" => 0.00001,
          "output_cost_per_token" => 0.00002
        }
      }
    end

    before do
      Ai::Price.delete_all
    end

    it "fetches from the live pricing registry and writes accurate rates to ai_prices table" do
      response_double = instance_double(Net::HTTPSuccess, body: sample_registry_payload.to_json)
      allow(response_double).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      http_double = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:open_timeout=)
      allow(http_double).to receive(:read_timeout=)
      allow(http_double).to receive(:get).and_return(response_double)

      described_class.sync!

      deepseek_price = Ai::Price.find_by(provider: "deepseek", model: "deepseek-chat")
      expect(deepseek_price).to be_present
      expect(deepseek_price.input_cost_per_million).to eq(0.14)
      expect(deepseek_price.cached_cost_per_million).to eq(0.014)
      expect(deepseek_price.output_cost_per_million).to eq(0.28)
      expect(deepseek_price.currency).to eq("usd")

      gemini_price = Ai::Price.find_by(provider: "gemini", model: "gemini-2.5-flash")
      expect(gemini_price).to be_present
      expect(gemini_price.input_cost_per_million).to eq(0.15)
      # Defaults to 50% of input cost when cached cost is omitted
      expect(gemini_price.cached_cost_per_million).to eq(0.075)
      expect(gemini_price.output_cost_per_million).to eq(0.60)

      # Untracked vendor is ignored
      expect(Ai::Price.find_by(model: "some-model")).to be_nil
    end

    it "handles network errors gracefully without raising" do
      allow(Net::HTTP).to receive(:new).and_raise(SocketError.new("Failed to open TCP connection"))

      expect { described_class.sync! }.not_to raise_error
      expect(Ai::Price.count).to eq(0)
    end
  end
end
