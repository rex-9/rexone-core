# app/constants/asset_constants/asset_format.rb

module AssetConstants
  module AssetFormat
    IMAGE = "image".freeze
    AUDIO = "audio".freeze
    VIDEO = "video".freeze
    DOC   = "doc".freeze
    ALL   = [ IMAGE, AUDIO, VIDEO, DOC ].freeze

    # ── Extension Mapping ──────────────────────────────────────────────
    # Single source of truth for file extension → format classification.

    IMAGE_EXTENSIONS = %w[jpg jpeg png gif webp svg].freeze
    AUDIO_EXTENSIONS = %w[mp3 wav m4a aac ogg flac].freeze
    VIDEO_EXTENSIONS = %w[mp4 mov avi webm mkv].freeze
    DOC_EXTENSIONS   = %w[pdf doc docx txt rtf].freeze

    EXTENSION_TO_FORMAT = (
      IMAGE_EXTENSIONS.to_h { |ext| [ ext, IMAGE ] }.merge(
        AUDIO_EXTENSIONS.to_h { |ext| [ ext, AUDIO ] },
        VIDEO_EXTENSIONS.to_h { |ext| [ ext, VIDEO ] },
        DOC_EXTENSIONS.to_h   { |ext| [ ext, DOC ] }
      )
    ).freeze

    # Storage provider resource type (e.g. Cloudinary: "image", "video", "raw").
    # Audio shares "video" resource type with most providers.
    EXTENSION_TO_STORAGE_RESOURCE_TYPE = (
      IMAGE_EXTENSIONS.to_h { |ext| [ ext, "image" ] }.merge(
        AUDIO_EXTENSIONS.to_h { |ext| [ ext, "video" ] },
        VIDEO_EXTENSIONS.to_h { |ext| [ ext, "video" ] },
        DOC_EXTENSIONS.to_h   { |ext| [ ext, "raw" ] }
      )
    ).freeze

    # ── Lookup Helpers ─────────────────────────────────────────────────

    # Returns the asset format for a file extension (e.g. "jpg" → "image").
    def self.from_extension(ext)
      EXTENSION_TO_FORMAT[ext.to_s.downcase]
    end

    # Returns the storage provider resource type (e.g. "jpg" → "image", "mp3" → "video").
    def self.storage_resource_type(ext)
      EXTENSION_TO_STORAGE_RESOURCE_TYPE[ext.to_s.downcase] || "auto"
    end
  end
end
