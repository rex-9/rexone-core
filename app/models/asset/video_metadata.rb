# frozen_string_literal: true

# app/models/asset/video_metadata.rb
# Deterministic metadata contract for Video assets.
class Asset
  class VideoMetadata < Metadata
    # Video display width in pixels (e.g. 1920). Must be a positive integer.
    attribute :width, :integer

    # Video display height in pixels (e.g. 1080). Must be a positive integer.
    attribute :height, :integer

    # Total stream bit rate in kilobits per second (kbps) or bits per second. Must be a positive integer.
    attribute :bitrate, :integer

    # Video playback duration in integer seconds. Must be non-negative.
    attribute :duration_secs, :integer

    # Video playback frame rate in frames per second (e.g. 23.976, 29.97, 60.0). Must be positive.
    attribute :fps, :float

    # Video compression codec name (e.g. "h264", "hevc", "vp9", "av1").
    attribute :codec, :string

    validates :width, :height, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :bitrate, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :duration_secs, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :fps, numericality: { greater_than: 0 }, allow_nil: true
  end
end
