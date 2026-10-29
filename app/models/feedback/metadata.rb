# frozen_string_literal: true

# app/models/feedback/metadata.rb
# Deterministic metadata contract for Feedback submissions.
class Feedback
  class Metadata < ApplicationMetadata
    # Client application version active when feedback was submitted.
    attribute :app_version, :string

    # App view or component name where feedback was initiated.
    attribute :screen, :string

    # Client-side router path or URL when the user submitted feedback.
    attribute :route, :string

    # User's language/locale preference (e.g. "en-US", "my-MM").
    attribute :locale, :string

    # Browser or client User-Agent string.
    attribute :user_agent, :string

    # Screen viewport dimensions at time of feedback (e.g. "390x844").
    attribute :viewport, :string
  end
end
