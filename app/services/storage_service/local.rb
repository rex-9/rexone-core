# app/services/storage_service/local.rb
# Not Used

module StorageService
  class Local < Base
    LOG_PREFIX = "[LocalStorage]".freeze

    def initialize
      @storage_path = AppConfig::LOCAL_STORAGE_PATH
      FileUtils.mkdir_p(@storage_path)
    end

    def upload(file, options = {})
      filename = options[:storage_key] || options[:filename] || generate_filename(file)
      folder = filename.to_s.include?("/") ? nil : (options[:folder] || "uploads")
      storage_key = folder ? File.join(folder, filename) : filename
      path = File.join(@storage_path, storage_key)

      FileUtils.mkdir_p(File.dirname(path))

      if file.is_a?(String)
        FileUtils.cp(file, path)
      else
        File.open(path, "wb") do |f|
          f.write(file.read)
        end
      end

      {
        storage_key: storage_key,
        url: "/storage/#{storage_key}",
        bytes: File.size(path),
        format: File.extname(filename).delete("."),
        created_at: Time.now,
        original_filename: filename,
        resource_type: options[:resource_type] || "auto"
      }
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Upload Error: #{e.message}")
      raise UploadError, e.message
    end

    def delete(identifier, options = {})
      path = get_full_path(identifier, options)

      if File.exist?(path)
        FileUtils.rm(path)
      end

      true
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Delete Error: #{e.message}")
      raise DeleteError, e.message
    end

    def url(identifier, options = {})
      "/storage/#{identifier}"
    end

    def move(source, destination, options = {})
      source_path = get_full_path(source, options)
      dest_path = get_full_path(destination, options)

      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.mv(source_path, dest_path)

      {
        storage_key: destination,
        url: "/storage/#{destination}"
      }
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Move Error: #{e.message}")
      raise Error, e.message
    end

    def copy(source, destination, options = {})
      source_path = get_full_path(source, options)
      dest_path = get_full_path(destination, options)

      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(source_path, dest_path)

      {
        storage_key: destination,
        url: "/storage/#{destination}"
      }
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Copy Error: #{e.message}")
      raise Error, e.message
    end

    def exists?(identifier)
      path = get_full_path(identifier)
      File.exist?(path)
    end

    def list(prefix = nil, options = {})
      search_path = File.join(@storage_path, prefix || "**/*")
      files = Dir.glob(search_path)

      files.map do |file|
        relative_path = file.gsub("#{@storage_path}/", "")
        {
          storage_key: relative_path,
          url: "/storage/#{relative_path}",
          bytes: File.size(file),
          format: File.extname(file).delete("."),
          created_at: File.ctime(file),
          resource_type: options[:resource_type] || "auto"
        }
      end
    end

    def download(identifier, destination_path = nil)
      source_path = get_full_path(identifier)
      raise Error, "File not found: #{identifier}" unless File.exist?(source_path)

      if destination_path
        FileUtils.cp(source_path, destination_path)
        destination_path
      else
        File.read(source_path)
      end
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Download Error: #{e.message}")
      raise Error, e.message
    end

    def storage_stats
      bytes = Dir.exist?(@storage_path) ? Dir.glob(File.join(@storage_path, "**", "*")).select { |f| File.file?(f) }.sum { |f| File.size(f) } : 0
      objects = Dir.exist?(@storage_path) ? Dir.glob(File.join(@storage_path, "**", "*")).count { |f| File.file?(f) } : 0

      {
        provider: "local",
        bucket: "local",
        bucket_bytes: bytes,
        bucket_objects: objects,
        disk_available_bytes: 0,
        disk_total_bytes: 0,
        disk_used_percent: nil,
        disk_free_percent: nil,
        node_capacity_bytes: 0
      }
    end

    private

    def get_full_path(identifier, options = {})
      storage_path = File.expand_path(@storage_path)
      base_path = if options[:folder].present?
        File.join(storage_path, options[:folder])
      else
        storage_path
      end

      path = File.expand_path(identifier, base_path)

      unless path.start_with?("#{storage_path}#{File::SEPARATOR}")
        raise Error, "Invalid storage identifier"
      end

      path
    end

    def generate_filename(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.original_filename, ".*")
      extension = file.is_a?(String) ? File.extname(file) : File.extname(file.original_filename)
      "#{basename}_#{Time.now.to_i}#{extension}"
    end
  end
end
