# frozen_string_literal: true

# app/models/asset/metadata.rb
# Deterministic metadata contract for media assets.
# Serves as the base class and polymorphic dispatcher for format-specific metadata:
# - Video: Asset::VideoMetadata (width, height, bitrate, duration_secs, fps, codec)
# - Audio: Asset::AudioMetadata (bitrate, channels, sample_rate, duration_secs)
# - Image: Asset::ImageMetadata (width, height)
# - Subtitle: Asset::SubtitleMetadata (content, language)
# - General / Unclassified: Asset::Metadata (original_filename)
class Asset
  class Metadata < ApplicationMetadata
    # Original filename of the client upload before storage key hashing or sanitization.
    attribute :original_filename, :string

    # Dispatches to the appropriate metadata class based on the asset's format and type.
    def self.for(format: nil, type: nil)
      case format.to_s.downcase
      when AssetConstants::AssetFormat::VIDEO then VideoMetadata
      when AssetConstants::AssetFormat::AUDIO then AudioMetadata
      when AssetConstants::AssetFormat::IMAGE then ImageMetadata
      else
        type.to_s.downcase == AssetConstants::AssetType::SUBTITLE ? SubtitleMetadata : self
      end
    end
  end
end
