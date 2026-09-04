# app/services/storage_service/s3.rb

require "aws-sdk-s3"
require "net/http"
require "uri"
require_relative "error"

module StorageService
  class S3 < Base
    LOG_PREFIX = "[S3]".freeze
    DEFAULT_FOLDER = "uploads".freeze
    DEFAULT_LIST_LIMIT = 100
    DOWNLOAD_OPEN_TIMEOUT_SECONDS = 10
    DOWNLOAD_READ_TIMEOUT_SECONDS = 30

    def initialize
      @bucket = require_config(AppConfig::S3_BUCKET, "S3_BUCKET")
      @client = build_client
    end

    def upload(file, options = {})
      source = resolve_source(file)
      key = build_key(options, source)

      raise UploadError, "Object already exists: #{key}" if options[:overwrite] == false && exists?(key)

      @client.put_object(
        bucket: @bucket,
        key: key,
        body: source[:body],
        content_type: resolve_content_type(source, key)
      )

      {
        storage_key: key,
        url: url(key),
        bytes: source[:body].bytesize,
        format: extension_of(key),
        created_at: Time.current,
        original_filename: source[:filename],
        resource_type: options[:resource_type]
      }
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      Rails.logger.error("#{LOG_PREFIX} Upload Error: #{e.message}")
      raise UploadError, e.message
    end

    def delete(identifier, options = {})
      @client.delete_object(bucket: @bucket, key: identifier)

      true
    rescue Aws::S3::Errors::NoSuchKey
      true
    rescue Aws::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Delete Error: #{e.message}")
      raise DeleteError, e.message
    end

    def url(identifier, options = {})
      "#{public_base_url}/#{identifier}"
    end

    def move(source, destination, options = {})
      result = copy(source, destination, options)
      delete(source, options)
      result
    end

    def copy(source, destination, options = {})
      @client.copy_object(
        bucket: @bucket,
        copy_source: URI::DEFAULT_PARSER.escape("/#{@bucket}/#{source}"),
        key: destination
      )

      {
        storage_key: destination,
        url: url(destination),
        bytes: content_length_of(destination),
        format: extension_of(destination),
        resource_type: options[:resource_type]
      }
    rescue Aws::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Copy Error: #{e.message}")
      raise UploadError, e.message
    end

    def exists?(identifier)
      @client.head_object(bucket: @bucket, key: identifier)

      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    rescue Aws::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} Exists? Error: #{e.message}")
      false
    end

    def list(prefix = nil, options = {})
      response = @client.list_objects_v2(
        bucket: @bucket,
        prefix: prefix.presence,
        max_keys: options[:limit] || DEFAULT_LIST_LIMIT
      )

      response.contents.map do |object|
        {
          storage_key: object.key,
          url: url(object.key),
          bytes: object.size,
          format: extension_of(object.key),
          created_at: object.last_modified,
          resource_type: options[:resource_type]
        }
      end
    rescue Aws::Errors::ServiceError => e
      Rails.logger.error("#{LOG_PREFIX} List Error: #{e.message}")
      []
    end

    private

    # Garage does not support virtual-host style addressing, so every request
    # must go through path style URLs. Expect: 100-continue is also disabled:
    # Garage (and many Coolify proxies) never send 100 Continue, so the AWS
    # SDK would hang in wait_for_continue until Net::ReadTimeout.
    def build_client
      Aws::S3::Client.new(
        endpoint: require_config(AppConfig::S3_ENDPOINT, "S3_ENDPOINT"),
        region: AppConfig::S3_REGION,
        access_key_id: require_config(AppConfig::S3_ACCESS_KEY_ID, "S3_ACCESS_KEY_ID"),
        secret_access_key: require_config(AppConfig::S3_SECRET_ACCESS_KEY, "S3_SECRET_ACCESS_KEY"),
        force_path_style: true,
        http_continue_timeout: 0
      )
    end

    def require_config(value, name)
      return value if value.present?

      raise Error, "Missing S3 configuration: #{name}"
    end

    def public_base_url
      base = AppConfig::S3_PUBLIC_BASE_URL.presence || "#{AppConfig::S3_ENDPOINT}/#{@bucket}"
      base.chomp("/")
    end

    # Callers pass extension-less keys because Cloudinary appends the format
    # itself. S3 stores the key verbatim, so the extension is added here.
    def build_key(options, source)
      folder = options[:folder].presence || DEFAULT_FOLDER
      base = options[:storage_key].presence || generate_storage_key(source[:filename])
      extension = File.extname(base).presence || derive_extension(source)

      File.join(folder.to_s, "#{base.delete_suffix(extension.to_s)}#{extension}")
    end

    def derive_extension(source)
      from_filename = File.extname(source[:filename].to_s)
      return from_filename if from_filename.present?

      from_content_type = StorageConstants::ContentType.extension_for(source[:content_type])
      from_content_type.present? ? ".#{from_content_type}" : ""
    end

    def generate_storage_key(filename)
      basename = File.basename(filename.to_s, ".*")
      basename = "file" if basename.blank?

      "#{basename}_#{Time.now.to_i}"
    end

    def extension_of(key)
      File.extname(key.to_s).delete(".").presence
    end

    def resolve_content_type(source, key)
      source[:content_type].presence ||
        StorageConstants::ContentType.for_extension(extension_of(key))
    end

    def content_length_of(key)
      @client.head_object(bucket: @bucket, key: key).content_length
    rescue Aws::Errors::ServiceError
      nil
    end

    def resolve_source(file)
      if file.is_a?(String)
        remote_url?(file) ? download(file) : read_path(file)
      elsif file.respond_to?(:original_filename)
        { body: read_io(file), filename: file.original_filename }
      elsif file.respond_to?(:read)
        { body: read_io(file), filename: filename_of(file) }
      elsif file.respond_to?(:path)
        read_path(file.path)
      else
        raise UploadError, "Unsupported upload source: #{file.class}"
      end
    end

    def filename_of(file)
      return nil unless file.respond_to?(:path)

      File.basename(file.path.to_s).presence
    end

    def read_path(path)
      { body: File.binread(path), filename: File.basename(path.to_s) }
    rescue SystemCallError => e
      Rails.logger.error("#{LOG_PREFIX} Read Error: #{e.message}")
      raise UploadError, e.message
    end

    def read_io(io)
      io.binmode if io.respond_to?(:binmode)
      io.rewind if io.respond_to?(:rewind)
      io.read.to_s.b
    end

    def remote_url?(value)
      value.start_with?("http://", "https://")
    end

    # Cloudinary fetches remote URLs server-side; S3 cannot, so the bytes are
    # pulled down here before being put into the bucket.
    def download(url)
      uri = URI.parse(url)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: DOWNLOAD_OPEN_TIMEOUT_SECONDS,
        read_timeout: DOWNLOAD_READ_TIMEOUT_SECONDS
      ) { |http| http.get(uri.request_uri) }

      unless (200..299).cover?(response.code.to_i)
        raise UploadError, "Could not fetch source URL (#{response.code}): #{url}"
      end

      {
        body: response.body.to_s.b,
        filename: File.basename(uri.path.to_s).presence,
        content_type: response["Content-Type"]
      }
    rescue UploadError
      raise
    rescue StandardError => e
      Rails.logger.error("#{LOG_PREFIX} Fetch Error: #{e.message}")
      raise UploadError, e.message
    end
  end
end
