# frozen_string_literal: true

require "administrate/base_dashboard"

class Ai::RunDashboard < Administrate::BaseDashboard
  def display_resource(run)
    "Ai::Run ##{run.id[0..7]} (#{run.feature})"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    profile: Field::BelongsTo.with_options(class_name: "Ai::Profile"),
    user: Field::BelongsTo,
    chat_message: Field::BelongsTo.with_options(class_name: "Chat::Message"),
    feature: Field::String,
    provider: Field::String,
    model: Field::String,
    status: Field::String,
    latency_ms: Field::Number,
    total_tokens: Field::Number,
    prompt_tokens: Field::Number,
    completion_tokens: Field::Number,
    input_messages_count: Field::Number,
    input_chars: Field::Number,
    output_chars: Field::Number,
    error: Field::Text,
    request_metadata: Field::String.with_options(searchable: false),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    discarded_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    feature
    profile
    model
    status
    total_tokens
    latency_ms
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    feature
    profile
    user
    chat_message
    provider
    model
    status
    latency_ms
    total_tokens
    prompt_tokens
    completion_tokens
    input_messages_count
    input_chars
    output_chars
    error
    request_metadata
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    profile
    user
    feature
    provider
    model
    status
  ].freeze

  COLLECTION_FILTERS = {}.freeze
end
