# frozen_string_literal: true

# app/constants/media_constants.rb
module MediaConstants
  # Feature flags
  MEDIA_CONTAINER_ENABLED = AppConfig::MEDIA_CONTAINER_ENABLED
  GARAGE_CONTAINER_ENABLED = AppConfig::GARAGE_CONTAINER_ENABLED

  # Upload size limits conditioned on MEDIA_CONTAINER_ENABLED (in MB)
  MAX_VIDEO_SIZE_MB = AppConfig::MEDIA_MAX_VIDEO_SIZE_MB
  MAX_AUDIO_SIZE_MB = AppConfig::MEDIA_MAX_AUDIO_SIZE_MB
  MAX_IMAGE_SIZE_MB = AppConfig::MEDIA_MAX_IMAGE_SIZE_MB
  MAX_OTHER_SIZE_MB = AppConfig::MEDIA_MAX_OTHER_SIZE_MB

  # Video compression profile
  VIDEO_CRF = AppConfig::MEDIA_VIDEO_CRF
  VIDEO_PRESET = AppConfig::MEDIA_VIDEO_PRESET
  VIDEO_MAX_WIDTH = AppConfig::MEDIA_VIDEO_MAX_WIDTH
  VIDEO_MAX_HEIGHT = AppConfig::MEDIA_VIDEO_MAX_HEIGHT
  VIDEO_MAX_BITRATE = AppConfig::MEDIA_VIDEO_MAX_BITRATE
  VIDEO_BUFFER_SIZE = AppConfig::MEDIA_VIDEO_BUFFER_SIZE
  VIDEO_AUDIO_BITRATE = AppConfig::MEDIA_VIDEO_AUDIO_BITRATE
  VIDEO_CODEC = AppConfig::MEDIA_VIDEO_CODEC
  VIDEO_AUDIO_CODEC = AppConfig::MEDIA_VIDEO_AUDIO_CODEC
  AUDIO_BITRATE = AppConfig::MEDIA_AUDIO_BITRATE
  AUDIO_CODEC = AppConfig::MEDIA_AUDIO_CODEC

  # Image compression profile
  IMAGE_JPEG_QUALITY = AppConfig::MEDIA_IMAGE_JPEG_QUALITY
  IMAGE_PNG_QUALITY = AppConfig::MEDIA_IMAGE_PNG_QUALITY
  IMAGE_PNG_COMPRESSION = AppConfig::MEDIA_IMAGE_PNG_COMPRESSION
  IMAGE_WEBP_QUALITY = AppConfig::MEDIA_IMAGE_WEBP_QUALITY
  IMAGE_MAX_WIDTH = AppConfig::MEDIA_IMAGE_MAX_WIDTH
  IMAGE_MAX_HEIGHT = AppConfig::MEDIA_IMAGE_MAX_HEIGHT

  # Maximum compression passes allowed (e.g., 1st pass on upload, 2nd manual pass by admin)
  MAX_COMPRESSION_PASSES = AppConfig::MEDIA_MAX_COMPRESSION_PASSES

  # Image format extensions
  IMAGE_EXT_JPG = "jpg".freeze
  IMAGE_EXT_JPEG = "jpeg".freeze
  IMAGE_EXT_PNG = "png".freeze
  IMAGE_EXT_WEBP = "webp".freeze
  IMAGE_EXT_SVG = "svg".freeze

  # Video format extensions
  VIDEO_EXT_MP4 = "mp4".freeze
  VIDEO_EXT_MOV = "mov".freeze
  VIDEO_EXT_AVI = "avi".freeze
  VIDEO_EXT_WEBM = "webm".freeze
  VIDEO_EXT_MKV = "mkv".freeze

  # Audio format extensions
  AUDIO_EXT_MP3 = "mp3".freeze
  AUDIO_EXT_WAV = "wav".freeze
  AUDIO_EXT_M4A = "m4a".freeze
  AUDIO_EXT_AAC = "aac".freeze
  AUDIO_EXT_OGG = "ogg".freeze
  AUDIO_EXT_FLAC = "flac".freeze
  AUDIO_EXT_AMR = "amr".freeze

  # Subtitle format extensions
  SUBTITLE_EXT_SRT = "srt".freeze
  SUBTITLE_CONTENT_TYPES = [ "application/x-subrip", "text/plain" ].freeze

  # Asset processing statuses
  module Status
    PENDING = "pending".freeze
    PROCESSING = "processing".freeze
    READY = "ready".freeze
    OPTIMAL = "optimal".freeze
    FAILED = "failed".freeze
    ALL = [ PENDING, PROCESSING, READY, OPTIMAL, FAILED ].freeze
  end

  # Socket event notification types
  module SocketEvent
    ASSET_COMPRESSING = "asset_compressing".freeze
    ASSET_COMPRESSED = "asset_compressed".freeze
    ASSET_COMPRESSION_FAILED = "asset_compression_failed".freeze
    ASSET_THUMBNAIL_PROCESSING = "asset_thumbnail_processing".freeze
    ASSET_THUMBNAIL_GENERATED = "asset_thumbnail_generated".freeze
    ASSET_THUMBNAIL_FAILED = "asset_thumbnail_failed".freeze
  end

  # Media processing capabilities. Update these lists when a processor gains or
  # loses support for a format; controllers and models consume the same source.
  module Processing
    COMPRESSION_EXTENSIONS = {
      AssetConstants::AssetFormat::VIDEO => [ VIDEO_EXT_MP4, VIDEO_EXT_MOV, VIDEO_EXT_AVI, VIDEO_EXT_WEBM, VIDEO_EXT_MKV ].freeze,
      AssetConstants::AssetFormat::IMAGE => [ IMAGE_EXT_JPG, IMAGE_EXT_JPEG, IMAGE_EXT_PNG, IMAGE_EXT_WEBP ].freeze,
      AssetConstants::AssetFormat::AUDIO => [ AUDIO_EXT_MP3, AUDIO_EXT_WAV, AUDIO_EXT_M4A, AUDIO_EXT_AAC, AUDIO_EXT_OGG, AUDIO_EXT_FLAC, AUDIO_EXT_AMR ].freeze
    }.freeze
    THUMBNAIL_GENERATION_EXTENSIONS = COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::VIDEO)
    IMAGE_CONVERSION_EXTENSIONS = [ IMAGE_EXT_SVG ].freeze
    ALL_EXTENSIONS = (COMPRESSION_EXTENSIONS.values.flatten + IMAGE_CONVERSION_EXTENSIONS).uniq.freeze
    CONCURRENCY_KEY_PREFIX = "asset-media-processing".freeze

    def self.concurrency_key(asset_id)
      "#{CONCURRENCY_KEY_PREFIX}:#{asset_id}"
    end
  end

  COMPRESSIBLE_VIDEO_EXTENSIONS = Processing::COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::VIDEO)
  COMPRESSIBLE_IMAGE_EXTENSIONS = Processing::COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::IMAGE)
  COMPRESSIBLE_AUDIO_EXTENSIONS = Processing::COMPRESSION_EXTENSIONS.fetch(AssetConstants::AssetFormat::AUDIO)
  # These input containers cannot host the configured AAC output; normalize them to M4A.
  AAC_INCOMPATIBLE_AUDIO_EXTENSIONS = [ AUDIO_EXT_WAV, AUDIO_EXT_FLAC, AUDIO_EXT_OGG, AUDIO_EXT_AMR ].freeze

  # Minimum reduction threshold (3%): if compression yields less than 3%, file is considered already at minimum size
  MIN_REDUCTION_THRESHOLD = 0.03
end
