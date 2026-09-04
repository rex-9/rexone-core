# app/constants/media_constants.rb
module MediaConstants
  # Feature flags
  MEDIA_CONTAINER_ENABLED = ENV.fetch("MEDIA_CONTAINER_ENABLED", "true") == "true"
  GARAGE_CONTAINER_ENABLED = ENV.fetch("GARAGE_CONTAINER_ENABLED", "false") == "true"

  # Upload size limits conditioned on MEDIA_CONTAINER_ENABLED (in MB)
  MAX_VIDEO_SIZE_MB = ENV.fetch("MEDIA_MAX_VIDEO_SIZE_MB", MEDIA_CONTAINER_ENABLED ? 100 : 10).to_i
  MAX_NON_VIDEO_SIZE_MB = ENV.fetch("MEDIA_MAX_NON_VIDEO_SIZE_MB", MEDIA_CONTAINER_ENABLED ? 10 : 1).to_i

  # Video compression profile (all consts so easily adjustable)
  VIDEO_CRF = ENV.fetch("MEDIA_VIDEO_CRF", "23").to_i
  VIDEO_PRESET = ENV.fetch("MEDIA_VIDEO_PRESET", "medium").freeze
  VIDEO_MAX_WIDTH = ENV.fetch("MEDIA_VIDEO_MAX_WIDTH", "1920").to_i
  VIDEO_MAX_HEIGHT = ENV.fetch("MEDIA_VIDEO_MAX_HEIGHT", "1080").to_i
  VIDEO_MAX_BITRATE = ENV.fetch("MEDIA_VIDEO_MAX_BITRATE", "5M").freeze
  VIDEO_BUFFER_SIZE = ENV.fetch("MEDIA_VIDEO_BUFFER_SIZE", "10M").freeze
  VIDEO_AUDIO_BITRATE = ENV.fetch("MEDIA_VIDEO_AUDIO_BITRATE", "128k").freeze
  VIDEO_CODEC = ENV.fetch("MEDIA_VIDEO_CODEC", "libx264").freeze
  VIDEO_AUDIO_CODEC = ENV.fetch("MEDIA_VIDEO_AUDIO_CODEC", "aac").freeze

  # Image compression profile
  IMAGE_JPEG_QUALITY = ENV.fetch("MEDIA_IMAGE_JPEG_QUALITY", "82").to_i
  IMAGE_PNG_QUALITY = ENV.fetch("MEDIA_IMAGE_PNG_QUALITY", "82").to_i
  IMAGE_PNG_COMPRESSION = ENV.fetch("MEDIA_IMAGE_PNG_COMPRESSION", "9").to_i
  IMAGE_WEBP_QUALITY = ENV.fetch("MEDIA_IMAGE_WEBP_QUALITY", "80").to_i
  IMAGE_MAX_WIDTH = ENV.fetch("MEDIA_IMAGE_MAX_WIDTH", "1920").to_i
  IMAGE_MAX_HEIGHT = ENV.fetch("MEDIA_IMAGE_MAX_HEIGHT", "1080").to_i

  # Maximum compression passes allowed (e.g., 1st pass on upload, 2nd manual pass by admin)
  MAX_COMPRESSION_PASSES = ENV.fetch("MEDIA_MAX_COMPRESSION_PASSES", "2").to_i

  # Image format extensions
  IMAGE_EXT_JPG = "jpg".freeze
  IMAGE_EXT_JPEG = "jpeg".freeze
  IMAGE_EXT_PNG = "png".freeze
  IMAGE_EXT_WEBP = "webp".freeze

  # Video format extensions
  VIDEO_EXT_MP4 = "mp4".freeze
  VIDEO_EXT_MOV = "mov".freeze
  VIDEO_EXT_AVI = "avi".freeze
  VIDEO_EXT_WEBM = "webm".freeze
  VIDEO_EXT_MKV = "mkv".freeze

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
  end

  # Compressible formats
  COMPRESSIBLE_VIDEO_EXTENSIONS = [ VIDEO_EXT_MP4, VIDEO_EXT_MOV, VIDEO_EXT_AVI, VIDEO_EXT_WEBM, VIDEO_EXT_MKV ].freeze
  COMPRESSIBLE_IMAGE_EXTENSIONS = [ IMAGE_EXT_JPG, IMAGE_EXT_JPEG, IMAGE_EXT_PNG, IMAGE_EXT_WEBP ].freeze

  # Minimum reduction threshold (3%): if compression yields less than 3%, file is considered already at minimum size
  MIN_REDUCTION_THRESHOLD = 0.03
end
