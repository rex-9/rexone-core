# frozen_string_literal: true

# app/models/ai/profile/settings.rb
# Deterministic settings contract for Ai::Profile generation configurations.
module Ai
  class Profile
    class Settings < ApplicationMetadata
      attribute :top_p, :float
      attribute :presence_penalty, :float
      attribute :frequency_penalty, :float
      attribute :stop_sequences
    end
  end
end
