# app/constants/storage_constants/provider.rb

module StorageConstants
  module Provider
    CLOUDINARY = "cloudinary".freeze
    LOCAL      = "local".freeze
    S3         = "s3".freeze
    ALL        = [ CLOUDINARY, LOCAL, S3 ].freeze
  end
end
