# app/constants/asset_constants/asset_type.rb

module AssetConstants
  module AssetType
    AVATAR     = "avatar".freeze
    THUMBNAIL  = "thumbnail".freeze
    AUDIO      = "audio".freeze
    VIDEO      = "video".freeze
    ATTACHMENT = "attachment".freeze
    GENERAL    = "general".freeze
    ALL        = [ AVATAR, THUMBNAIL, AUDIO, VIDEO, ATTACHMENT, GENERAL ].freeze
    IMAGE_TYPES = [ AVATAR, THUMBNAIL ].freeze
  end
end
