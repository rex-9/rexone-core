# app/constants/asset_constants/asset_name.rb

module AssetConstants
  module AssetName
    TTS_MESSAGE_PREFIX = "tts_message_".freeze

    def self.google_profile(user_id)
      "users/#{user_id}/avatar_google_#{Time.now.to_i}".freeze
    end

    def self.tts_for_message(message_id)
      "admin/audio_tts_message_#{message_id}_#{Time.now.to_i}.mp3".freeze
    end

    def self.for_admin(type:, original_filename:)
      ext = File.extname(original_filename.to_s).downcase
      base = File.basename(original_filename.to_s, ext).parameterize(separator: "_").presence || "asset"
      "admin/#{type}_#{base}_#{Time.now.to_i}#{ext}".freeze
    end

    def self.for_user(user_id:, type:, original_filename:)
      ext = File.extname(original_filename.to_s).downcase
      base = File.basename(original_filename.to_s, ext).parameterize(separator: "_").presence || "asset"
      "users/#{user_id}/#{type}_#{base}_#{Time.now.to_i}#{ext}".freeze
    end

    def self.rename_type(old_key, new_type, user_id = nil)
      return old_key if old_key.blank? || new_type.blank?

      key_str = old_key.to_s
      if key_str.start_with?("admin/")
        filename = key_str.delete_prefix("admin/")
        parts = filename.split("_", 2)
        new_filename = parts.length > 1 ? "#{new_type}_#{parts[1]}" : "#{new_type}_#{filename}"
        "admin/#{new_filename}".freeze
      elsif key_str.start_with?("users/")
        segments = key_str.split("/", 3)
        if segments.length == 3
          uid = segments[1]
          filename = segments[2]
          parts = filename.split("_", 2)
          new_filename = parts.length > 1 ? "#{new_type}_#{parts[1]}" : "#{new_type}_#{filename}"
          "users/#{uid}/#{new_filename}".freeze
        else
          "users/#{user_id || 'general'}/#{new_type}_#{File.basename(key_str)}".freeze
        end
      else
        ext = File.extname(key_str)
        base = File.basename(key_str, ext)
        parts = base.split("_", 2)
        rest = parts.length > 1 ? parts[1] : base
        if user_id.present?
          "users/#{user_id}/#{new_type}_#{rest}#{ext}".freeze
        else
          "admin/#{new_type}_#{rest}#{ext}".freeze
        end
      end
    end
  end
end
