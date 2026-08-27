# app/constants/asset_constants/asset_type.rb

module AssetConstants
  module AssetType
    AVATAR     = "avatar".freeze
    COVER      = "cover".freeze
    CARD       = "card".freeze
    AUDIO      = "audio".freeze
    VIDEO      = "video".freeze
    ATTACHMENT = "attachment".freeze
    GENERAL    = "general".freeze
    ALL        = [ AVATAR, COVER, CARD, AUDIO, VIDEO, ATTACHMENT, GENERAL ].freeze
  end
end
