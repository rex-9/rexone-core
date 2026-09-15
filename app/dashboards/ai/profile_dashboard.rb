# frozen_string_literal: true

require "administrate/base_dashboard"

class Ai::ProfileDashboard < Administrate::BaseDashboard
  def display_resource(profile)
    "#{profile.name} (#{profile.key})"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    key: Field::String,
    name: Field::String,
    provider: Field::String,
    model: Field::String,
    enabled: Field::Boolean,
    temperature: Field::Number.with_options(decimals: 2),
    max_output_tokens: Field::Number,
    context_max_tokens: Field::Number,
    history_max_messages: Field::Number,
    timeout_seconds: Field::Number,
    system_prompt: Field::Text,
    settings: Field::String.with_options(searchable: false),
    runs: Field::HasMany.with_options(class_name: "Ai::Run"),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    discarded_at: Field::DateTime,
    undiscarded_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    key
    name
    provider
    model
    enabled
    temperature
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    key
    name
    provider
    model
    enabled
    temperature
    max_output_tokens
    context_max_tokens
    history_max_messages
    timeout_seconds
    system_prompt
    settings
    runs
    created_at
    updated_at
    discarded_at
    undiscarded_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    key
    name
    provider
    model
    enabled
    temperature
    max_output_tokens
    context_max_tokens
    history_max_messages
    timeout_seconds
    system_prompt
  ].freeze

  COLLECTION_FILTERS = {}.freeze
end
