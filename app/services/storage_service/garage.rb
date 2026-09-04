# app/services/storage_service/garage.rb

require_relative "error"

module StorageService
  class Garage < Base
    LOG_PREFIX = "[Garage]".freeze

    def initialize
      require "aws-sdk-s3"

      @bucket = AppConfig::S3_BUCKET
      @public_endpoint = AppConfig::S3_PUBLIC_ENDPOINT

      common_options = {
        access_key_id: AppConfig::S3_ACCESS_KEY,
        secret_access_key: AppConfig::S3_SECRET_KEY,
        region: AppConfig::S3_REGION,
        force_path_style: true
      }

      @client = Aws::S3::Client.new(
        common_options.merge(endpoint: AppConfig::S3_ENDPOINT)
      )

      @public_client = Aws::S3::Client.new(
        common_options.merge(endpoint: @public_endpoint)
      )
    rescue KeyError => e
      raise Error, "Missing Garage configuration: #{e.message}"
    end

    def upload(file, options = {})
      storage_key = options[:storage_key] || generate_storage_key(file)
      if options[:folder].present? && !storage_key.to_s.include?("/")
        storage_key = File.join(options[:folder], storage_key)
      end

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

    def storage_stats
      admin_endpoint = AppConfig::S3_ADMIN_ENDPOINT
      admin_token = AppConfig::S3_ADMIN_TOKEN

      require "net/http"
      require "json"

      disk_avail = 0
      disk_total = 0
      node_capacity = 0

      # 1. Query Node & Cluster Status
      begin
        status_uri = URI("#{admin_endpoint}/v1/status")
        status_req = Net::HTTP::Get.new(status_uri)
        status_req["Authorization"] = "Bearer #{admin_token}"

        status_res = Net::HTTP.start(status_uri.host, status_uri.port, open_timeout: 2, read_timeout: 3) do |http|
          http.request(status_req)
        end

        if status_res.is_a?(Net::HTTPSuccess)
          status_data = JSON.parse(status_res.body)
          node = status_data["nodes"]&.first
          if node
            disk_avail = node.dig("dataPartition", "available").to_i
            disk_total = node.dig("dataPartition", "total").to_i
            node_capacity = node.dig("role", "capacity").to_i
          end
        end
      rescue => e
        Rails.logger.warn("#{LOG_PREFIX} Could not fetch cluster status: #{e.message}")
      end

      # 2. Query Bucket Stats
      bucket_bytes = 0
      bucket_objects = 0

      begin
        bucket_search_uri = URI("#{admin_endpoint}/v1/bucket?search=#{@bucket}")
        bucket_search_req = Net::HTTP::Get.new(bucket_search_uri)
        bucket_search_req["Authorization"] = "Bearer #{admin_token}"

        bucket_search_res = Net::HTTP.start(bucket_search_uri.host, bucket_search_uri.port, open_timeout: 2, read_timeout: 3) do |http|
          http.request(bucket_search_req)
        end

        if bucket_search_res.is_a?(Net::HTTPSuccess)
          buckets = JSON.parse(bucket_search_res.body)
          bucket_info = buckets.find { |b| b["globalAliases"]&.include?(@bucket) }
          if bucket_info && bucket_info["id"]
            detail_uri = URI("#{admin_endpoint}/v1/bucket?id=#{bucket_info['id']}")
            detail_req = Net::HTTP::Get.new(detail_uri)
            detail_req["Authorization"] = "Bearer #{admin_token}"
            detail_res = Net::HTTP.start(detail_uri.host, detail_uri.port, open_timeout: 2, read_timeout: 3) do |http|
              http.request(detail_req)
            end
            if detail_res.is_a?(Net::HTTPSuccess)
              detail = JSON.parse(detail_res.body)
              bucket_bytes = detail["bytes"].to_i
              bucket_objects = detail["objects"].to_i
            end
          end
        end
      rescue => e
        Rails.logger.warn("#{LOG_PREFIX} Could not fetch bucket details: #{e.message}")
      end

      if bucket_bytes == 0 && defined?(Asset)
        bucket_bytes = Asset.kept.where(source: AssetConstants::AssetSource::UPLOAD).sum(:size_bytes).to_i
        bucket_objects = Asset.kept.where(source: AssetConstants::AssetSource::UPLOAD).count
      end

      disk_used_percent = disk_total.positive? ? (((disk_total - disk_avail).to_f / disk_total) * 100).round(1) : nil
      disk_free_percent = disk_total.positive? ? ((disk_avail.to_f / disk_total) * 100).round(1) : nil

      {
        provider: "garage",
        bucket: @bucket,
        bucket_bytes: bucket_bytes,
        bucket_objects: bucket_objects,
        disk_available_bytes: disk_avail,
        disk_total_bytes: disk_total,
        disk_used_percent: disk_used_percent,
        disk_free_percent: disk_free_percent,
        node_capacity_bytes: node_capacity
      }
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Storage stats error: #{e.message}")
      {
        provider: "garage",
        bucket: @bucket,
        bucket_bytes: 0,
        bucket_objects: 0,
        disk_available_bytes: 0,
        disk_total_bytes: 0,
        disk_used_percent: nil,
        disk_free_percent: nil,
        node_capacity_bytes: 0,
        error: e.message
      }
    end

    private

    def generate_storage_key(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.respond_to?(:original_filename) ? file.original_filename : "upload", ".*")
      "#{basename}_#{Time.now.to_i}"
    end
  end
end
