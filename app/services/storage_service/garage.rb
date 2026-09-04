# app/services/storage_service/garage.rb

require_relative "error"

module StorageService
  class Garage < Base
    LOG_PREFIX = "[Garage]".freeze

    def initialize
      require "aws-sdk-s3"

      @bucket = ENV.fetch("S3_BUCKET", "rexone")
      @public_endpoint = ENV.fetch("S3_PUBLIC_ENDPOINT", "http://localhost:3100")

      common_options = {
        access_key_id: ENV.fetch("S3_ACCESS_KEY", ""),
        secret_access_key: ENV.fetch("S3_SECRET_KEY", ""),
        region: ENV.fetch("S3_REGION", "garage"),
        force_path_style: true
      }

      @client = Aws::S3::Client.new(
        common_options.merge(endpoint: ENV.fetch("S3_ENDPOINT", "http://garage:3100"))
      )

      @public_client = Aws::S3::Client.new(
        common_options.merge(endpoint: @public_endpoint)
      )
    rescue KeyError => e
      raise Error, "Missing Garage configuration: #{e.message}"
    end

    def upload(file, options = {})
      storage_key = options[:storage_key] || generate_storage_key(file)

      body = file.is_a?(String) ? File.open(file, "rb") : file
      original_filename = file.is_a?(String) ? File.basename(file) : (file.respond_to?(:original_filename) ? file.original_filename : "upload")
      format = File.extname(original_filename.to_s).delete(".").downcase.presence || "unknown"
      bytes = file.is_a?(String) ? File.size(file) : file.size
      content_type = options[:content_type] || Rack::Mime.mime_type(File.extname(original_filename.to_s), "application/octet-stream")

      @client.put_object(
        bucket: @bucket,
        key: storage_key,
        body: body,
        content_type: content_type
      )

      {
        storage_key: storage_key,
        url: url(storage_key),
        bytes: bytes,
        format: format,
        original_filename: original_filename,
        resource_type: options[:resource_type] || "auto"
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Upload Error: #{e.message}")
      raise UploadError, e.message
    ensure
      body.close if body.is_a?(File)
    end

    def delete(identifier, options = {})
      @client.delete_object(bucket: @bucket, key: identifier)
      true
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Delete Error: #{e.message}")
      raise DeleteError, e.message
    end

    def url(identifier, options = {})
      expiry = options[:expiry] || 7.days.to_i

      presign_params = {
        bucket: @bucket,
        key: identifier,
        expires_in: expiry
      }

      content_type = options[:response_content_type] || options[:content_type]
      content_type ||= Rack::Mime.mime_type(File.extname(identifier.to_s), nil)
      presign_params[:response_content_type] = content_type if content_type.present?

      disposition = options[:response_content_disposition] || options[:disposition]
      presign_params[:response_content_disposition] = disposition if disposition.present?

      signer = Aws::S3::Presigner.new(client: @public_client)
      signer.presigned_url(:get_object, **presign_params)
    rescue Aws::S3::Errors::ServiceError, ArgumentError => e
      Rails.logger.error("#{LOG_PREFIX} URL presigning error: #{e.message}")
      "#{@public_endpoint}/#{@bucket}/#{identifier}"
    end

    def move(source, destination, options = {})
      result = copy(source, destination, options)
      delete(source, options)
      result
    end

    def copy(source, destination, options = {})
      @client.copy_object(
        bucket: @bucket,
        copy_source: "#{@bucket}/#{source}",
        key: destination
      )

      head = @client.head_object(bucket: @bucket, key: destination)

      {
        storage_key: destination,
        url: url(destination),
        bytes: head.content_length,
        format: File.extname(destination).delete(".").downcase.presence || "unknown",
        resource_type: options[:resource_type] || "auto"
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Copy Error: #{e.message}")
      raise UploadError, e.message
    end

    def exists?(identifier)
      @client.head_object(bucket: @bucket, key: identifier)
      true
    rescue Aws::S3::Errors::NotFound
      false
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Exists? Error: #{e.message}")
      false
    end

    def list(prefix = nil, options = {})
      result = @client.list_objects_v2(
        bucket: @bucket,
        prefix: prefix,
        max_keys: options[:limit] || 100
      )

      result.contents.map do |object|
        {
          storage_key: object.key,
          url: url(object.key),
          bytes: object.size,
          format: File.extname(object.key).delete(".").downcase.presence || "unknown",
          created_at: object.last_modified.iso8601,
          resource_type: "auto"
        }
      end
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} List Error: #{e.message}")
      []
    end

    def generate_signed_url(identifier, options = {})
      expiry = options[:expiry] || 3600

      signer = Aws::S3::Presigner.new(client: @public_client)
      signed_url = signer.presigned_url(
        :get_object,
        bucket: @bucket,
        key: identifier,
        expires_in: expiry
      )

      {
        url: signed_url,
        expiry: Time.now + expiry,
        signature: nil
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Signed URL Error: #{e.message}")
      raise Error, e.message
    end

    def download(identifier, destination_path = nil)
      if destination_path
        @client.get_object(bucket: @bucket, key: identifier, response_target: destination_path)
        destination_path
      else
        response = @client.get_object(bucket: @bucket, key: identifier)
        response.body.read
      end
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Download Error: #{e.message}")
      raise Error, e.message
    end

    private

    def generate_storage_key(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.respond_to?(:original_filename) ? file.original_filename : "upload", ".*")
      "#{basename}_#{Time.now.to_i}"
    end
  end
end
