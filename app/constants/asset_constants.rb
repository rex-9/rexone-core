# frozen_string_literal: true

# app/constants/asset_constants.rb
module AssetConstants
  module AssetFormat
    IMAGE    = "image".freeze
    AUDIO    = "audio".freeze
    VIDEO    = "video".freeze
    DOC      = "doc".freeze
    SUBTITLE = "subtitle".freeze
    ALL      = [ IMAGE, AUDIO, VIDEO, DOC, SUBTITLE ].freeze

    # ── Extension Mapping ──────────────────────────────────────────────
    # Single source of truth for file extension → format classification.

    IMAGE_EXTENSIONS    = %w[jpg jpeg png gif webp svg].freeze
    AUDIO_EXTENSIONS    = %w[mp3 wav m4a aac ogg flac].freeze
    VIDEO_EXTENSIONS    = %w[mp4 mov avi webm mkv].freeze
    DOC_EXTENSIONS      = %w[pdf doc docx txt rtf].freeze
    SUBTITLE_EXTENSIONS = %w[srt].freeze

    EXTENSION_TO_FORMAT = (
      IMAGE_EXTENSIONS.to_h { |ext| [ ext, IMAGE ] }.merge(
        AUDIO_EXTENSIONS.to_h { |ext| [ ext, AUDIO ] },
        VIDEO_EXTENSIONS.to_h { |ext| [ ext, VIDEO ] },
        DOC_EXTENSIONS.to_h   { |ext| [ ext, DOC ] },
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
  end

  module AssetName
    TTS_MESSAGE_PREFIX = "tts_message_".freeze
    ADMIN_NAMESPACE = "admin".freeze
    USER_NAMESPACE = "user".freeze

    def self.google_profile(user_id)
      "#{USER_NAMESPACE}/#{user_id}/avatar_google_#{Time.now.to_i}".freeze
    end

    def self.tts_for_message(message_id)
      "#{ADMIN_NAMESPACE}/audio_tts_message_#{message_id}_#{Time.now.to_i}.mp3".freeze
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

    def self.rename_type(old_key, new_type, user_id = nil)
      return old_key if old_key.blank? || new_type.blank?

      key_str = old_key.to_s
      if key_str.start_with?("#{ADMIN_NAMESPACE}/")
        filename = key_str.delete_prefix("#{ADMIN_NAMESPACE}/")
        parts = filename.split("_", 2)
        new_filename = parts.length > 1 ? "#{new_type}_#{parts[1]}" : "#{new_type}_#{filename}"
        "#{ADMIN_NAMESPACE}/#{new_filename}".freeze
      elsif key_str.start_with?("#{USER_NAMESPACE}/")
        segments = key_str.split("/", 3)
        if segments.length == 3
          uid = segments[1]
          filename = segments[2]
          parts = filename.split("_", 2)
          new_filename = parts.length > 1 ? "#{new_type}_#{parts[1]}" : "#{new_type}_#{filename}"
          "#{USER_NAMESPACE}/#{uid}/#{new_filename}".freeze
        else
          "#{USER_NAMESPACE}/#{user_id || 'general'}/#{new_type}_#{File.basename(key_str)}".freeze
        end
      else
        ext = File.extname(key_str)
        base = File.basename(key_str, ext)
        parts = base.split("_", 2)
        rest = parts.length > 1 ? parts[1] : base
        if user_id.present?
          "#{USER_NAMESPACE}/#{user_id}/#{new_type}_#{rest}#{ext}".freeze
        else
          "#{ADMIN_NAMESPACE}/#{new_type}_#{rest}#{ext}".freeze
        end
      end
    end
  end

  module AssetSource
    UPLOAD = "upload".freeze
    GOOGLE = "google".freeze
  end

  module AssetType
    AVATAR     = "avatar".freeze
    THUMBNAIL  = "thumbnail".freeze
    SUBTITLE   = "subtitle".freeze
    AUDIO      = "audio".freeze
    VIDEO      = "video".freeze
    ATTACHMENT = "attachment".freeze
    GENERAL    = "general".freeze
    ALL        = [ AVATAR, THUMBNAIL, SUBTITLE, AUDIO, VIDEO, ATTACHMENT, GENERAL ].freeze
    IMAGE_TYPES = [ AVATAR, THUMBNAIL ].freeze
  end
end
