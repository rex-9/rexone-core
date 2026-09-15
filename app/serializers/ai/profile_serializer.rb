# frozen_string_literal: true

class Ai::ProfileSerializer < ApplicationSerializer
  attributes :key,
             :name,
             :enabled,
             :provider,
             :model

  attribute :temperature do |profile|
    profile.temperature&.to_f
  end

  attributes :max_output_tokens,
             :context_max_tokens,
             :history_max_messages,
             :timeout_seconds,
             :system_prompt,
             :settings,
             :created_at,
             :updated_at
end
