# frozen_string_literal: true

# app/models/asset/subtitle_metadata.rb
# Deterministic metadata contract for Subtitle assets.
class Asset
  class SubtitleMetadata < Metadata
    # Raw or parsed subtitle text content (e.g. WebVTT or SubRip SRT formatted cues).
    attribute :content, :string

    # Standard BCP 47 or ISO 639-1 language code of the subtitle track (e.g. "en", "es", "ja", "my").
    attribute :language, :string
  end
end
