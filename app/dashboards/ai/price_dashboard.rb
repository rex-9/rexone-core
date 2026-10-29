# frozen_string_literal: true

require "administrate/base_dashboard"

class Ai::PriceDashboard < Administrate::BaseDashboard
  def display_resource(price)
    "#{price.provider.upcase}: #{price.model} ($#{price.input_cost_per_million}/$#{price.output_cost_per_million} per 1M)"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    provider: Field::String,
    model: Field::String,
    currency: Field::String,
    input_cost_per_million: Field::Number.with_options(decimals: 6, prefix: "$"),
    cached_cost_per_million: Field::Number.with_options(decimals: 6, prefix: "$"),
    output_cost_per_million: Field::Number.with_options(decimals: 6, prefix: "$"),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    discarded_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    provider
    model
    currency
    input_cost_per_million
    cached_cost_per_million
    output_cost_per_million
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    provider
    model
    currency
    input_cost_per_million
    cached_cost_per_million
    output_cost_per_million
    created_at
    updated_at
    discarded_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    provider
    model
    currency
    input_cost_per_million
    cached_cost_per_million
    output_cost_per_million
  ].freeze

  COLLECTION_FILTERS = {}.freeze
end
