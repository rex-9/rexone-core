# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::CostCalculator do
  before do
    [
      { provider: "deepseek", model: "deepseek-chat", input: 0.14, cached: 0.014, output: 0.28 },
      { provider: "deepseek", model: "deepseek-reasoner", input: 0.55, cached: 0.14, output: 2.19 },
      { provider: "gemini", model: "gemini-2.5-flash", input: 0.15, cached: 0.0375, output: 0.60 },
      { provider: "gemini", model: "gemini-2.5-pro", input: 1.25, cached: 0.3125, output: 5.00 },
      { provider: "openai", model: "gpt-4o-mini", input: 0.15, cached: 0.075, output: 0.60 },
      { provider: "openai", model: "gpt-4o", input: 2.50, cached: 1.25, output: 10.00 },
      { provider: "openai", model: "o1", input: 15.00, cached: 7.50, output: 60.00 },
      { provider: "anthropic", model: "claude-3-5-sonnet", input: 3.00, cached: 0.30, output: 15.00 }
    ].each do |rate|
      Ai::Price.create!(
        provider: rate[:provider],
        model: rate[:model],
        currency: "usd",
        input_cost_per_million: rate[:input],
        cached_cost_per_million: rate[:cached],
        output_cost_per_million: rate[:output]
      )
    end
  end

  describe ".calculate" do
    describe "cheap models" do
      context "with DeepSeek Chat (cheap flagship model)" do
        # Rates: input = $0.14 / 1M, cached = $0.014 / 1M, output = $0.28 / 1M
        it "calculates precise cost for small user query (15 prompt, 8 completion)" do
          # 15 * 0.14 / 1M = 0.0000021
          # 8 * 0.28 / 1M  = 0.00000224
          # Total = 0.00000434 -> rounded to 6 decimals = 0.000004
          cost = described_class.calculate(
            provider: "deepseek",
            model: "deepseek-chat",
            prompt_tokens: 15,
            completion_tokens: 8,
            cached_tokens: 0
          )
          expect(cost).to eq(0.000004)
        end

        it "calculates accurate cost for standard conversational turn (1,000 prompt, 500 completion)" do
          # 1,000 * 0.14 / 1M = 0.00014
          # 500 * 0.28 / 1M   = 0.00014
          # Total = 0.00028
          cost = described_class.calculate(
            provider: "deepseek",
            model: "deepseek-chat",
            prompt_tokens: 1_000,
            completion_tokens: 500,
            cached_tokens: 0
          )
          expect(cost).to eq(0.00028)
        end
      end

      context "with Gemini 2.5 Flash / 3.8 Flash (high-throughput low-cost model)" do
        # Rates: input = $0.15 / 1M, cached = $0.0375 / 1M, output = $0.60 / 1M
        it "calculates cost for 50,000 prompt tokens and 10,000 completion tokens" do
          # 50k * 0.15 / 1M = 0.0075
          # 10k * 0.60 / 1M = 0.0060
          # Total = 0.0135
          cost = described_class.calculate(
            provider: "gemini",
            model: "gemini-2.5-flash",
            prompt_tokens: 50_000,
            completion_tokens: 10_000,
            cached_tokens: 0
          )
          expect(cost).to eq(0.0135)
        end
      end

      context "with GPT-4o-mini (OpenAI budget model)" do
        # Rates: input = $0.15 / 1M, cached = $0.075 / 1M, output = $0.60 / 1M
        it "calculates cost for 100,000 prompt tokens and 20,000 completion tokens" do
          # 100k * 0.15 / 1M = 0.015
          # 20k * 0.60 / 1M = 0.012
          # Total = 0.027
          cost = described_class.calculate(
            provider: "openai",
            model: "gpt-4o-mini",
            prompt_tokens: 100_000,
            completion_tokens: 20_000
          )
          expect(cost).to eq(0.027)
        end
      end
    end

    describe "expensive models" do
      context "with DeepSeek Reasoner (R1 reasoning model)" do
        # Rates: input = $0.55 / 1M, cached = $0.14 / 1M, output = $2.19 / 1M
        it "calculates cost accurately for heavy reasoning trace" do
          # 10,000 prompt, 4,000 reasoning output
          # 10k * 0.55 / 1M = 0.0055
          # 4k * 2.19 / 1M = 0.00876
          # Total = 0.01426
          cost = described_class.calculate(
            provider: "deepseek",
            model: "deepseek-reasoner",
            prompt_tokens: 10_000,
            completion_tokens: 4_000
          )
          expect(cost).to eq(0.01426)
        end
      end

      context "with GPT-4o (OpenAI flagship expensive model)" do
        # Rates: input = $2.50 / 1M, cached = $1.25 / 1M, output = $10.00 / 1M
        it "calculates cost for large enterprise workload" do
          # 200,000 prompt, 50,000 completion
          # 200k * 2.50 / 1M = 0.50
          # 50k * 10.00 / 1M = 0.50
          # Total = 1.00
          cost = described_class.calculate(
            provider: "openai",
            model: "gpt-4o",
            prompt_tokens: 200_000,
            completion_tokens: 50_000
          )
          expect(cost).to eq(1.0)
        end
      end

      context "with Gemini 2.5 Pro / 3.8 Pro" do
        # Rates: input = $1.25 / 1M, cached = $0.3125 / 1M, output = $5.00 / 1M
        it "calculates cost for complex reasoning analysis" do
          # 100,000 prompt, 10,000 completion
          # 100k * 1.25 / 1M = 0.125
          # 10k * 5.00 / 1M = 0.05
          # Total = 0.175
          cost = described_class.calculate(
            provider: "gemini",
            model: "gemini-2.5-pro",
            prompt_tokens: 100_000,
            completion_tokens: 10_000
          )
          expect(cost).to eq(0.175)
        end
      end

      context "with OpenAI o1 (ultra-expensive reasoning model)" do
        # Rates: input = $15.00 / 1M, cached = $7.50 / 1M, output = $60.00 / 1M
        it "calculates cost for heavy chain-of-thought execution" do
          # 50,000 prompt, 10,000 completion
          # 50k * 15.00 / 1M = 0.75
          # 10k * 60.00 / 1M = 0.60
          # Total = 1.35
          cost = described_class.calculate(
            provider: "openai",
            model: "o1",
            prompt_tokens: 50_000,
            completion_tokens: 10_000
          )
          expect(cost).to eq(1.35)
        end
      end

      context "with Anthropic Claude 3.5 Sonnet" do
        # Rates: input = $3.00 / 1M, cached = $0.30 / 1M, output = $15.00 / 1M
        it "calculates cost for coding assistant sessions" do
          # 80,000 prompt, 8,000 completion
          # 80k * 3.00 / 1M = 0.24
          # 8k * 15.00 / 1M = 0.12
          # Total = 0.36
          cost = described_class.calculate(
            provider: "anthropic",
            model: "claude-3-5-sonnet",
            prompt_tokens: 80_000,
            completion_tokens: 8_000
          )
          expect(cost).to eq(0.36)
        end
      end
    end

    describe "prompt caching discounts" do
      context "with DeepSeek 90% prompt cache discount" do
        it "bills cached tokens at $0.014/1M instead of $0.14/1M" do
          # 100k prompt tokens total: 80k cached, 20k uncached; 0 completion
          # uncached: 20,000 * 0.14 / 1M = 0.0028
          # cached:   80,000 * 0.014 / 1M = 0.00112
          # Total = 0.00392
          cost = described_class.calculate(
            provider: "deepseek",
            model: "deepseek-chat",
            prompt_tokens: 100_000,
            completion_tokens: 0,
            cached_tokens: 80_000
          )
          expect(cost).to eq(0.00392)
        end

        it "bills fully cached prompts at purely cached rate" do
          # 100k prompt tokens, all 100k cached
          # 100,000 * 0.014 / 1M = 0.0014
          cost = described_class.calculate(
            provider: "deepseek",
            model: "deepseek-chat",
            prompt_tokens: 100_000,
            completion_tokens: 0,
            cached_tokens: 100_000
          )
          expect(cost).to eq(0.0014)
        end
      end

      context "with Gemini 75% prompt cache discount" do
        it "bills cached tokens at $0.0375/1M instead of $0.15/1M" do
          # 1,000,000 prompt tokens total: 750,000 cached, 250,000 uncached
          # uncached: 250,000 * 0.15 / 1M   = 0.0375
          # cached:   750,000 * 0.0375 / 1M = 0.028125
          # Total = 0.065625
          cost = described_class.calculate(
            provider: "gemini",
            model: "gemini-2.5-flash",
            prompt_tokens: 1_000_000,
            completion_tokens: 0,
            cached_tokens: 750_000
          )
          expect(cost).to eq(0.065625)
        end
      end

      it "safely caps cached_tokens if provider usage reports more cached than prompt" do
        cost = described_class.calculate(
          provider: "deepseek",
          model: "deepseek-chat",
          prompt_tokens: 10_000,
          completion_tokens: 0,
          cached_tokens: 50_000
        )
        # Should cap cached at 10,000 tokens (10k * 0.014 / 1M = 0.00014)
        expect(cost).to eq(0.00014)
      end
    end

    describe "edge cases and robustness" do
      it "returns 0.0 for zero tokens" do
        expect(described_class.calculate(
          provider: "deepseek",
          model: "deepseek-chat",
          prompt_tokens: 0,
          completion_tokens: 0
        )).to eq(0.0)
      end

      it "handles nil token parameters gracefully without raising error" do
        expect(described_class.calculate(
          provider: "deepseek",
          model: "deepseek-chat",
          prompt_tokens: nil,
          completion_tokens: nil,
          cached_tokens: nil
        )).to eq(0.0)
      end

      it "handles negative token numbers safely" do
        expect(described_class.calculate(
          provider: "deepseek",
          model: "deepseek-chat",
          prompt_tokens: -100,
          completion_tokens: -50,
          cached_tokens: -20
        )).to eq(0.0)
      end

      it "strips provider prefixes from model names (e.g. openai/gpt-4o)" do
        cost_prefixed = described_class.calculate(
          provider: "openai",
          model: "openai/gpt-4o",
          prompt_tokens: 100_000,
          completion_tokens: 10_000
        )
        cost_clean = described_class.calculate(
          provider: "openai",
          model: "gpt-4o",
          prompt_tokens: 100_000,
          completion_tokens: 10_000
        )
        expect(cost_prefixed).to eq(cost_clean)
      end

      it "is case-insensitive for provider and model strings" do
        cost_upper = described_class.calculate(
          provider: "OPENAI",
          model: "GPT-4O-MINI",
          prompt_tokens: 100_000,
          completion_tokens: 10_000
        )
        cost_lower = described_class.calculate(
          provider: "openai",
          model: "gpt-4o-mini",
          prompt_tokens: 100_000,
          completion_tokens: 10_000
        )
        expect(cost_upper).to eq(cost_lower)
      end
    end

    describe "dynamic database pricing & precedence" do
      let!(:custom_price) do
        Ai::Price.create!(
          provider: "custom-ai",
          model: "neural-pro-v1",
          currency: "USD",
          input_cost_per_million: 5.0,
          cached_cost_per_million: 1.0,
          output_cost_per_million: 20.0
        )
      end

      it "uses active database records when present" do
        # 100k prompt (40k cached, 60k uncached), 20k completion
        # uncached: 60k * 5.0 / 1M  = 0.30
        # cached:   40k * 1.0 / 1M  = 0.04
        # output:   20k * 20.0 / 1M = 0.40
        # Total = 0.74
        cost = described_class.calculate(
          provider: "custom-ai",
          model: "neural-pro-v1",
          prompt_tokens: 100_000,
          completion_tokens: 20_000,
          cached_tokens: 40_000
        )
        expect(cost).to eq(0.74)
      end

      it "ignores soft-deleted (discarded) price records and returns 0.0" do
        custom_price.update!(discarded_at: Time.current)

        cost = described_class.calculate(
          provider: "custom-ai",
          model: "neural-pro-v1",
          prompt_tokens: 100_000,
          completion_tokens: 10_000
        )
        expect(cost).to eq(0.0)
      end
    end
  end
end
