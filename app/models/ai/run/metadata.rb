# frozen_string_literal: true

# app/models/ai/run/metadata.rb
# Deterministic metadata contract for Ai::Run executions.
module Ai
  class Run
    class Metadata < ApplicationMetadata
      # Provider API endpoint invoked for this AI inference run (e.g. "chat/completions", "images/generations").
      attribute :endpoint, :string

      # Chat room UUID associated with this inference execution if conversational.
      attribute :room_id, :string

      # Target natural language code requested for generation or translation (e.g. "en", "es").
      attribute :language, :string

      # Specific pipeline analysis task (e.g. "sentiment", "summary", "extraction").
      attribute :analysis_type, :string
    end
  end
end
