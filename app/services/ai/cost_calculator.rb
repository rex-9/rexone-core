# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

module Ai
  class CostCalculator
    class << self
      def calculate(provider:, model:, prompt_tokens:, completion_tokens:, cached_tokens: 0)
        rates = resolve_rates(provider: provider.to_s.downcase, model: model.to_s.downcase)

        prompt = [ prompt_tokens.to_i, 0 ].max
        completion = [ completion_tokens.to_i, 0 ].max
        cached = [ [ cached_tokens.to_i, 0 ].max, prompt ].min
        uncached_prompt = prompt - cached

        divisor = AiConstants::Pricing::PER_MILLION.to_d
        precision = AiConstants::Pricing::DECIMAL_PRECISION

        input_rate = rates[:input].to_d
        cached_rate = rates[:cached].to_d
        output_rate = rates[:output].to_d

        input_cost = (uncached_prompt.to_d * input_rate) / divisor
        cached_cost = (cached.to_d * cached_rate) / divisor
        output_cost = (completion.to_d * output_rate) / divisor

        (input_cost + cached_cost + output_cost).round(precision).to_f
      end

      private

      def resolve_rates(provider:, model:)
        clean_model = model.sub(%r{^[^/]+/}, "")

        record = Ai::Price.kept.find_by(provider: provider, model: model) ||
                 Ai::Price.kept.find_by(provider: provider, model: clean_model) ||
                 Ai::Price.kept.find_by(model: clean_model)

        if record
          return {
            input: record.input_cost_per_million.to_d,
            cached: record.cached_cost_per_million.to_d,
            output: record.output_cost_per_million.to_d
          }
        end

        {
          input: 0.0.to_d,
          cached: 0.0.to_d,
          output: 0.0.to_d
        }
      end
    end
  end
end
