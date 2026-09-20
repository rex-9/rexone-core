# app/services/storage_service/garage.rb

require_relative "error"

module StorageService
  class Garage < Base
    LOG_PREFIX = "[Garage]".freeze
    ENVIRONMENT_PREFIXES = AssetConstants::ENVIRONMENT_PREFIXES

    attr_reader :client, :public_client

    def initialize
      require "aws-sdk-s3"

      @bucket = AppConfig::S3_BUCKET
      @public_endpoint = AppConfig::S3_PUBLIC_ENDPOINT

      @common_options = {
        access_key_id: AppConfig::S3_ACCESS_KEY,
        secret_access_key: AppConfig::S3_SECRET_KEY,
        region: AppConfig::S3_REGION,
        force_path_style: true
      }

      @client = Aws::S3::Client.new(
        @common_options.merge(endpoint: AppConfig::S3_ENDPOINT)
      )

      @public_client = Aws::S3::Client.new(
        @common_options.merge(endpoint: @public_endpoint)
      )
    rescue KeyError => e
      raise Error, "Missing Garage configuration: #{e.message}"
    end

    def public_client_for(public_host = nil)
      return @public_client if public_host.blank?

      uri = URI.parse(@public_endpoint)
      host_only = public_host.to_s.split(":").first
      return @public_client if host_only.blank? || host_only == uri.host

      dynamic_endpoint = "#{uri.scheme}://#{host_only}:#{uri.port}"
      Aws::S3::Client.new(
        @common_options.merge(endpoint: dynamic_endpoint)
      )
    rescue URI::InvalidURIError
      @public_client
    end

    def upload(file, options = {})
      storage_key = options[:storage_key] || generate_storage_key(file)
      if options[:folder].present? && !storage_key.to_s.include?("/")
        storage_key = File.join(options[:folder], storage_key)
      end
      storage_key = apply_prefix(storage_key)

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
      key = apply_prefix(identifier)
      @client.delete_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Delete Error: #{e.message}")
      raise DeleteError, e.message
    end

    def url(identifier, options = {})
      key = apply_prefix(identifier)
      expiry = options[:expiry] || 7.days.to_i

      presign_params = {
        bucket: @bucket,
        key: key,
        expires_in: expiry
      }

      content_type = options[:response_content_type].presence || Rack::Mime.mime_type(File.extname(key.to_s), nil)
      presign_params[:response_content_type] = content_type if content_type.present?

      disposition = options[:response_content_disposition]
      presign_params[:response_content_disposition] = disposition if disposition.present?

      target_client = public_client_for(options[:public_host])
      signer = Aws::S3::Presigner.new(client: target_client)
      signer.presigned_url(:get_object, **presign_params)
    rescue Aws::S3::Errors::ServiceError, ArgumentError => e
      Rails.logger.error("#{LOG_PREFIX} URL presigning error: #{e.message}")
      "#{@public_endpoint}/#{@bucket}/#{key}"
    end

    def move(source, destination, options = {})
      result = copy(source, destination, options)
      delete(source, options)
      result
    end

    def copy(source, destination, options = {})
      target_source = apply_prefix(source)
      target_destination = apply_prefix(destination)

      @client.copy_object(
        bucket: @bucket,
        copy_source: "#{@bucket}/#{target_source}",
        key: target_destination
      )

      head = @client.head_object(bucket: @bucket, key: target_destination)

      {
        storage_key: target_destination,
        url: url(target_destination),
        bytes: head.content_length,
        format: File.extname(target_destination).delete(".").downcase.presence || "unknown",
        resource_type: options[:resource_type] || "auto"
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Copy Error: #{e.message}")
      raise UploadError, e.message
    end

    def exists?(identifier)
      key = apply_prefix(identifier)
      @client.head_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Exists? Error: #{e.message}")
      false
    end

    def list(prefix = nil, options = {})
      effective_prefix = if folder_prefix
        if prefix.blank?
          "#{folder_prefix}/"
        elsif prefix.to_s.start_with?("#{folder_prefix}/")
          prefix.to_s
        else
          "#{folder_prefix}/#{prefix.to_s.sub(%r{\A/+}, '')}"
        end
      else
        prefix
      end

      result = @client.list_objects_v2(
        bucket: @bucket,
        prefix: effective_prefix,
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
      key = apply_prefix(identifier)
      expiry = options[:expiry] || 3600

      signer = Aws::S3::Presigner.new(client: @public_client)
      signed_url = signer.presigned_url(
        :get_object,
        bucket: @bucket,
        key: key,
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

    def playback_url(asset, expires_in:, public_host: nil)
      key = apply_prefix(asset.storage_key)
      content_type = Rack::Mime.mime_type(".#{asset.extension}", "application/octet-stream")

      target_client = public_client_for(public_host)
      signer = Aws::S3::Presigner.new(client: target_client)
      signed_url = signer.presigned_url(
        :get_object,
        bucket: @bucket,
        key: key,
        expires_in: expires_in,
        response_content_type: content_type,
        response_content_disposition: "inline"
      )

      {
        type: MediaConstants::Playback::DELIVERY_TYPE_PROGRESSIVE,
        url: signed_url,
        expires_at: Time.current + expires_in.seconds
      }
    rescue Aws::S3::Errors::ServiceError, ArgumentError => e
      Rails.logger.error("#{LOG_PREFIX} Playback URL Error: #{e.message}")
      raise Error, e.message
    end

    def download(identifier, destination_path = nil)
      key = apply_prefix(identifier)
      if destination_path
        @client.get_object(bucket: @bucket, key: key, response_target: destination_path)
        destination_path
      else
        response = @client.get_object(bucket: @bucket, key: key)
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
        partitions: environment_partition_stats,
        tracked_partitions: database_environment_partition_stats,
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
        partitions: empty_environment_partition_stats,
        tracked_partitions: empty_environment_partition_stats,
        disk_available_bytes: 0,
        disk_total_bytes: 0,
        disk_used_percent: nil,
        disk_free_percent: nil,
        node_capacity_bytes: 0,
        error: e.message
      }
    end

    private

    def environment_partition_stats
      ENVIRONMENT_PREFIXES.index_with do |prefix|
        bytes = 0
        objects = 0
        continuation_token = nil

        loop do
          options = { bucket: @bucket, prefix: "#{prefix}/" }
          options[:continuation_token] = continuation_token if continuation_token.present?
          response = @client.list_objects_v2(**options)

          bytes += response.contents.sum(&:size)
          objects += response.contents.size
          break unless response.is_truncated

          continuation_token = response.next_continuation_token
        end

        { bytes: bytes, objects: objects }
      end
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.warn("#{LOG_PREFIX} Could not fetch environment partition stats: #{e.message}")
      empty_environment_partition_stats
    end

    def empty_environment_partition_stats
      ENVIRONMENT_PREFIXES.index_with { { bytes: 0, objects: 0 } }
    end

    def database_environment_partition_stats
      return empty_environment_partition_stats unless defined?(Asset)

      ENVIRONMENT_PREFIXES.index_with do |prefix|
        scope = Asset.kept.where("storage_key LIKE ?", "#{prefix}/%")
        { bytes: scope.sum(:size_bytes).to_i, objects: scope.count }
      end
    end

    def folder_prefix
      raw = if defined?(AppConfig::S3_FOLDER_PREFIX)
              AppConfig::S3_FOLDER_PREFIX
      else
              ENV["S3_FOLDER_PREFIX"]
      end
      raw.to_s.strip.gsub(%r{\A/+|/+$}, "").presence
    end

    def apply_prefix(key)
      return key.to_s if key.blank?
      return key.to_s unless folder_prefix

      normalized_key = key.to_s.sub(%r{\A/+}, "")
      return normalized_key if ENVIRONMENT_PREFIXES.any? { |prefix| normalized_key.start_with?("#{prefix}/") }

      "#{folder_prefix}/#{normalized_key}"
    end

    def generate_storage_key(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.respond_to?(:original_filename) ? file.original_filename : "upload", ".*")
      "#{basename}_#{Time.now.to_i}"
    end
  end
end
