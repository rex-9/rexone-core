# frozen_string_literal: true

# app/models/asset/audio_metadata.rb
# Deterministic metadata contract for Audio assets.
class Asset
  class AudioMetadata < Metadata
    # Audio bit rate in kilobits per second (kbps) (e.g. 128, 256, 320). Must be a positive integer.
    attribute :bitrate, :integer

    # Number of discrete audio channels (e.g. 1 for mono, 2 for stereo, 6 for 5.1 surround). Must be a positive integer.
    attribute :channels, :integer

    # Audio sampling frequency in Hertz (Hz) (e.g. 44100, 48000). Must be a positive integer.
    attribute :sample_rate, :integer

    # Audio playback duration in integer seconds. Must be non-negative.
    attribute :duration_secs, :integer

    validates :bitrate, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :channels, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :sample_rate, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :duration_secs, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  end
end
