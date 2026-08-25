# app/constants/asset_constants/asset_name.rb

module AssetConstants
  module AssetName
    GOOGLE_PROFILE_PREFIX = "profile_google_of_user_".freeze

    def self.google_profile(user_id)
      "#{GOOGLE_PROFILE_PREFIX}#{user_id}".freeze
    end
  end
end
