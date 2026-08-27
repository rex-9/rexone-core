# app/services/storage_service/cloudinary.rb

require "cloudinary"
require "cloudinary/uploader"

module StorageService
  class Cloudinary < Base
    Cloudinary = ::Cloudinary
    LOG_PREFIX = "[Cloudinary]".freeze

    def initialize
      Cloudinary.config do |config|
        config.cloud_name = ENV.fetch("CLOUDINARY_CLOUD_NAME")
        config.api_key = ENV.fetch("CLOUDINARY_API_KEY")
        config.api_secret = ENV.fetch("CLOUDINARY_API_SECRET")
        config.secure = true
      end
    rescue KeyError => e
      raise Error, "Missing Cloudinary configuration: #{e.message}"
    end

    def upload(file, options = {})
      storage_key = options[:storage_key] || generate_storage_key(file)
      folder = options[:folder] || "uploads"

      result = Cloudinary::Uploader.upload(
        file.is_a?(String) ? file : file.path,
        {
          public_id: storage_key,
          folder: folder,
          resource_type: options[:resource_type] || "auto",
          overwrite: options[:overwrite] || true,
          eager: options[:eager] || [],
          eager_async: options[:eager_async] || false,
          use_filename: options[:use_filename] || false,
          unique_filename: options[:unique_filename] || false
        }.compact
      )

      {
        storage_key: result["public_id"],
        url: result["secure_url"],
        bytes: result["bytes"],
        format: result["format"],
        width: result["width"],
        height: result["height"],
        created_at: result["created_at"],
        original_filename: result["original_filename"],
        resource_type: result["resource_type"]
      }
    rescue ::CloudinaryException => e
      Rails.logger.error("#{LOG_PREFIX} Upload Error: #{e.message}")
      raise UploadError, e.message
    end

    def delete(identifier, options = {})
      resource_type = options[:resource_type] || "image"
      result = Cloudinary::Uploader.destroy(identifier, resource_type: resource_type)

      unless %w[ok not\ found].include?(result["result"])
        raise DeleteError, result["error"]["message"] if result["error"]
        raise DeleteError, "Failed to delete asset"
      end

      true
    rescue ::CloudinaryException => e
      Rails.logger.error("#{LOG_PREFIX} Delete Error: #{e.message}")
      raise DeleteError, e.message
    end

    def url(identifier, options = {})
      transformation = options[:transformation] || []
      resource_type = options[:resource_type] || "image"

      Cloudinary::Utils.cloudinary_url(
        identifier,
        {
          resource_type: resource_type,
          secure: true,
          transformation: transformation
        }.compact
      )
    end

    def move(source, destination, options = {})
      # Cloudinary doesn't directly support move, use copy + delete
      copy_result = copy(source, destination, options)
      delete(source, options)
      copy_result
    end

    def copy(source, destination, options = {})
      result = Cloudinary::Uploader.upload(
        url(source),
        {
          public_id: destination,
          folder: options[:folder],
          overwrite: options[:overwrite] || true
        }.compact
      )

      {
        storage_key: result["public_id"],
        url: result["secure_url"],
        bytes: result["bytes"],
        format: result["format"],
        resource_type: result["resource_type"]
      }
    rescue ::CloudinaryException => e
      Rails.logger.error("#{LOG_PREFIX} Copy Error: #{e.message}")
      raise UploadError, e.message
    end

    def exists?(identifier)
      Cloudinary::Api.resource(identifier)
      true
    rescue Cloudinary::Api::NotFound
      false
    rescue ::CloudinaryException => e
      Rails.logger.error("#{LOG_PREFIX} Exists? Error: #{e.message}")
      false
    end

    def list(prefix = nil, options = {})
      result = Cloudinary::Api.resources(
        prefix: prefix,
        max_results: options[:limit] || 100,
        resource_type: options[:resource_type] || "image",
        type: options[:type] || "upload"
      )

      result["resources"].map do |resource|
        {
          storage_key: resource["public_id"],
          url: resource["secure_url"],
          bytes: resource["bytes"],
          format: resource["format"],
          width: resource["width"],
          height: resource["height"],
          created_at: resource["created_at"],
          resource_type: resource["resource_type"]
        }
      end
    rescue ::CloudinaryException => e
      Rails.logger.error("#{LOG_PREFIX} List Error: #{e.message}")
      []
    end

    def generate_signed_url(identifier, options = {})
      expiry = options[:expiry] || 3600
      transformation = options[:transformation] || []

      timestamp = Time.now.to_i + expiry
      signature = Cloudinary::Utils.api_sign_request(
        {
          public_id: identifier,
          timestamp: timestamp,
          transformation: transformation.join("/")
        },
        ENV.fetch("CLOUDINARY_API_SECRET")
      )

      {
        url: url(identifier, transformation: transformation),
        expiry: Time.at(timestamp),
        signature: signature
      }
    end

    private

    def generate_storage_key(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.original_filename, ".*")
      "#{basename}_#{Time.now.to_i}"
    end
  end
end
