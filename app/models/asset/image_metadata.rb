# frozen_string_literal: true

# app/models/asset/image_metadata.rb
# Deterministic metadata contract for Image and Thumbnail assets.
class Asset
  class ImageMetadata < Metadata
    # Image frame width in pixels (e.g. 1024, 1920). Must be a positive integer.
    attribute :width, :integer

    # Image frame height in pixels (e.g. 1024, 1080). Must be a positive integer.
    attribute :height, :integer

    validates :width, :height, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  end
end
