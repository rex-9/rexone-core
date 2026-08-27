# app/constants/asset_constants/asset_format.rb

module AssetConstants
  module AssetFormat
    IMAGE = "image".freeze
    AUDIO = "audio".freeze
    VIDEO = "video".freeze
    DOC   = "doc".freeze
    ALL   = [ IMAGE, AUDIO, VIDEO, DOC ].freeze
  end
end
