# frozen_string_literal: true

# app/constants/asset_constants.rb
module AssetConstants
  module AssetFormat
    IMAGE    = "image".freeze
    AUDIO    = "audio".freeze
    VIDEO    = "video".freeze
    DOC      = "doc".freeze
    ZIP      = "zip".freeze
    SUBTITLE = "subtitle".freeze
    ALL      = [ IMAGE, AUDIO, VIDEO, DOC, ZIP, SUBTITLE ].freeze

    # ── Extension Mapping ──────────────────────────────────────────────
    # Single source of truth for file extension → format classification.

    IMAGE_EXTENSIONS    = %w[jpg jpeg png gif webp svg].freeze
    AUDIO_EXTENSIONS    = %w[mp3 wav m4a aac ogg flac amr].freeze
    VIDEO_EXTENSIONS    = %w[mp4 mov avi webm mkv].freeze
    DOC_EXTENSIONS      = %w[pdf doc docx txt rtf].freeze
    ZIP_EXTENSIONS      = %w[zip].freeze
    SUBTITLE_EXTENSIONS = %w[srt].freeze

    EXTENSION_TO_FORMAT = (
      IMAGE_EXTENSIONS.to_h { |ext| [ ext, IMAGE ] }.merge(
        AUDIO_EXTENSIONS.to_h { |ext| [ ext, AUDIO ] },
        VIDEO_EXTENSIONS.to_h { |ext| [ ext, VIDEO ] },
        DOC_EXTENSIONS.to_h   { |ext| [ ext, DOC ] },
        ZIP_EXTENSIONS.to_h   { |ext| [ ext, ZIP ] },
        SUBTITLE_EXTENSIONS.to_h { |ext| [ ext, SUBTITLE ] }
      )
    ).freeze

    # Storage provider resource type (e.g. Cloudinary: "image", "video", "raw").
    # Audio shares "video" resource type with most providers.
    EXTENSION_TO_STORAGE_RESOURCE_TYPE = (
      IMAGE_EXTENSIONS.to_h { |ext| [ ext, "image" ] }.merge(
        AUDIO_EXTENSIONS.to_h { |ext| [ ext, "video" ] },
        VIDEO_EXTENSIONS.to_h { |ext| [ ext, "video" ] },
        DOC_EXTENSIONS.to_h   { |ext| [ ext, "raw" ] },
        ZIP_EXTENSIONS.to_h   { |ext| [ ext, "raw" ] },
        SUBTITLE_EXTENSIONS.to_h { |ext| [ ext, "raw" ] }
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

    def self.upload_limit_mb(ext)
      case from_extension(ext)
      when VIDEO then MediaConstants::MAX_VIDEO_SIZE_MB
      when AUDIO then MediaConstants::MAX_AUDIO_SIZE_MB
      when IMAGE then MediaConstants::MAX_IMAGE_SIZE_MB
      else MediaConstants::MAX_OTHER_SIZE_MB
      end
    end
  end

  module StoragePartition
    DEV  = "dev".freeze
    UAT  = "uat".freeze
    PROD = "prod".freeze
    ALL  = [ DEV, UAT, PROD ].freeze
  end

  STORAGE_PARTITIONS = StoragePartition::ALL
  ENVIRONMENT_PREFIXES = StoragePartition::ALL

  module AssetName
    TTS_MESSAGE_PREFIX = "tts_message_".freeze
    TTS_FOLDER = "tts".freeze
    ADMIN_NAMESPACE = "admin".freeze
    USER_NAMESPACE = "user".freeze

    def self.google_profile(user_id)
      "#{USER_NAMESPACE}/#{user_id}/avatar_google_#{Time.now.to_i}".freeze
    end

    def self.tts_for_message(message_id, user_id:)
      "#{USER_NAMESPACE}/#{user_id}/#{TTS_FOLDER}/#{TTS_MESSAGE_PREFIX}#{message_id}_#{Time.now.to_i}.mp3".freeze
    end

    def self.for_admin(type:, original_filename:)
      ext = File.extname(original_filename.to_s).downcase
      base = File.basename(original_filename.to_s, ext).parameterize(separator: "_").presence || "asset"
      "#{ADMIN_NAMESPACE}/#{type}_#{base}_#{Time.now.to_i}#{ext}".freeze
    end

    def self.for_user(user_id:, type:, original_filename:)
      ext = File.extname(original_filename.to_s).downcase
      base = File.basename(original_filename.to_s, ext).parameterize(separator: "_").presence || "asset"
      "#{USER_NAMESPACE}/#{user_id}/#{type}_#{base}_#{Time.now.to_i}#{ext}".freeze
    end

    def self.thumbnail_for(asset, version: nil, extension: MediaConstants::IMAGE_EXT_WEBP)
      suffix = version.present? ? "_#{version}" : ""
      ext = extension.to_s.delete(".").presence || MediaConstants::IMAGE_EXT_WEBP
      "#{File.dirname(asset.storage_key)}/thumbnail_#{asset.id}#{suffix}.#{ext}".freeze
    end

    def self.subtitle_for(asset, version: nil, extension: MediaConstants::SUBTITLE_EXT_SRT)
      suffix = version.present? ? "_#{version}" : ""
      ext = extension.to_s.delete(".").presence || MediaConstants::SUBTITLE_EXT_SRT
      "#{File.dirname(asset.storage_key)}/subtitle_#{asset.id}#{suffix}.#{ext}".freeze
    end

    def self.with_extension(storage_key, extension)
      key = storage_key.to_s
      target_extension = ".#{extension.to_s.delete('.')}"
      current_extension = File.extname(key)
      current_extension.present? ? key.delete_suffix(current_extension) + target_extension : key + target_extension
    end

    def self.rename_type(old_key, new_type, old_type = nil)
      return old_key if old_key.blank? || new_type.blank?

      key_str = old_key.to_s
      dir = File.dirname(key_str)
      filename = File.basename(key_str)

      new_filename = if old_type.present? && filename.start_with?("#{old_type}_")
        "#{new_type}_#{filename.delete_prefix("#{old_type}_")}"
      elsif (matched_type = AssetConstants::AssetType::ALL.find { |t| filename.start_with?("#{t}_") })
        "#{new_type}_#{filename.delete_prefix("#{matched_type}_")}"
      else
        parts = filename.split("_", 2)
        if parts.length > 1
          "#{new_type}_#{parts[1]}"
        else
          "#{new_type}_#{filename}"
        end
      end

      (dir == "." ? new_filename : "#{dir}/#{new_filename}").freeze
    end
  end

  module AssetSource
    UPLOAD = "upload".freeze
    GOOGLE = "google".freeze
  end

  module RecordScope
    PARENTS = "parents".freeze
    CHILDREN = "children".freeze
    ALL = "all".freeze
    VALUES = [ PARENTS, CHILDREN, ALL ].freeze
  end

  module AssetType
    AVATAR     = "avatar".freeze
    THUMBNAIL  = "thumbnail".freeze
    SUBTITLE   = "subtitle".freeze
    TTS        = "tts".freeze
    ATTACHMENT = "attachment".freeze
    GENERAL    = "general".freeze
    ALL        = [ AVATAR, THUMBNAIL, SUBTITLE, TTS, ATTACHMENT, GENERAL ].freeze
    IMAGE_TYPES = [ AVATAR, THUMBNAIL ].freeze
    CHILD_TYPES = [ THUMBNAIL, SUBTITLE ].freeze

    def self.child_type?(type)
      CHILD_TYPES.include?(type.to_s)
    end
  end
end
