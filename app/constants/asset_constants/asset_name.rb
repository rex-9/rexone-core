# app/constants/asset_constants/asset_name.rb

module AssetConstants
  module AssetName
    GOOGLE_PROFILE_PREFIX = "google_avatar_user_".freeze
    TTS_MESSAGE_PREFIX = "tts_message_".freeze

    def self.google_profile(user_id)
      "#{GOOGLE_PROFILE_PREFIX}#{user_id}".freeze
    end

    def self.tts_for_message(message_id)
      "#{TTS_MESSAGE_PREFIX}#{message_id}".freeze
    end
  end
end
