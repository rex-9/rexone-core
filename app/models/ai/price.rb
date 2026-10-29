# frozen_string_literal: true

module Ai
  class Price < ApplicationRecord
    self.table_name = "ai_prices"

    before_validation :normalize_currency

    validates :provider, presence: true
    validates :model, presence: true
    validates :currency, presence: true
    validates :input_cost_per_million, numericality: { greater_than_or_equal_to: 0 }
    validates :cached_cost_per_million, numericality: { greater_than_or_equal_to: 0 }
    validates :output_cost_per_million, numericality: { greater_than_or_equal_to: 0 }

    private

    def normalize_currency
      self.currency = currency.to_s.strip.downcase.presence || AiConstants::Pricing::DEFAULT_CURRENCY
    end
  end
end
