# app/services/storage_service/s3.rb
# Not Used

require "aws-sdk-s3"

module StorageService
  class S3 < Base
    def initialize
      @client = Aws::S3::Client.new(
        region: ENV.fetch("AWS_REGION", "us-east-1"),
        access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
        endpoint: ENV["AWS_ENDPOINT"], # For MinIO or other S3-compatible services
        force_path_style: ENV["AWS_FORCE_PATH_STYLE"] == "true"
      )
      @bucket = ENV.fetch("AWS_S3_BUCKET")
    rescue KeyError => e
      raise Error, "Missing S3 configuration: #{e.message}"
    end

    def upload(file, options = {})
      key = options[:key] || generate_key(file)
      folder = options[:folder] || "uploads"
      full_key = "#{folder}/#{key}"

      if file.is_a?(String)
        File.open(file, "rb") do |f|
          @client.put_object(
            bucket: @bucket,
            key: full_key,
            body: f,
            content_type: options[:content_type] || "application/octet-stream",
            acl: options[:acl] || "public-read",
            metadata: options[:metadata] || {}
          )
        end
      else
        @client.put_object(
          bucket: @bucket,
          key: full_key,
          body: file,
          content_type: options[:content_type] || "application/octet-stream",
          acl: options[:acl] || "public-read",
          metadata: options[:metadata] || {}
        )
      end

      {
        public_id: full_key,
        url: url(full_key),
        bytes: file.is_a?(String) ? File.size(file) : file.size,
        format: File.extname(key).delete("."),
        created_at: Time.now,
        original_filename: key,
        resource_type: options[:resource_type] || "auto"
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] Upload Error: #{e.message}")
      raise UploadError, e.message
    end

    def delete(identifier, options = {})
      @client.delete_object(
        bucket: @bucket,
        key: identifier
      )
      true
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] Delete Error: #{e.message}")
      raise DeleteError, e.message
    end

    def url(identifier, options = {})
      if ENV["AWS_CLOUDFRONT_DOMAIN"].present?
        "https://#{ENV['AWS_CLOUDFRONT_DOMAIN']}/#{identifier}"
      else
        @client.get_object_url(
          bucket: @bucket,
          key: identifier
        )
      end
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] URL Generation Error: #{e.message}")
      nil
    end

    def move(source, destination, options = {})
      @client.copy_object(
        bucket: @bucket,
        copy_source: "/#{@bucket}/#{source}",
        key: destination
      )
      delete(source)

      {
        public_id: destination,
        url: url(destination)
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] Move Error: #{e.message}")
      raise Error, e.message
    end

    def copy(source, destination, options = {})
      @client.copy_object(
        bucket: @bucket,
        copy_source: "/#{@bucket}/#{source}",
        key: destination
      )

      {
        public_id: destination,
        url: url(destination)
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] Copy Error: #{e.message}")
      raise Error, e.message
    end

    def exists?(identifier)
      @client.head_object(bucket: @bucket, key: identifier)
      true
    rescue Aws::S3::Errors::NotFound
      false
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] Exists? Error: #{e.message}")
      false
    end

    def list(prefix = nil, options = {})
      params = {
        bucket: @bucket,
        max_keys: options[:limit] || 100
      }
      params[:prefix] = prefix if prefix.present?

      response = @client.list_objects_v2(params)

      response.contents.map do |obj|
        {
          public_id: obj.key,
          url: url(obj.key),
          bytes: obj.size,
          format: File.extname(obj.key).delete("."),
          created_at: obj.last_modified,
          resource_type: options[:resource_type] || "auto",
          etag: obj.etag.delete('"')
        }
      end
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] List Error: #{e.message}")
      []
    end

    def generate_presigned_url(identifier, options = {})
      expiry = options[:expiry] || 3600

      signer = Aws::S3::Presigner.new(client: @client)
      signer.presigned_url(
        :get_object,
        bucket: @bucket,
        key: identifier,
        expires_in: expiry
      )
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("[S3] Presigned URL Error: #{e.message}")
      nil
    end

    private

    def generate_key(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.original_filename, ".*")
      extension = file.is_a?(String) ? File.extname(file) : File.extname(file.original_filename)
      "#{basename}_#{Time.now.to_i}#{extension}"
    end
  end
end
