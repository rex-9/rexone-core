# app/services/storage_service/local.rb
# Not Used

module StorageService
  class Local < Base
    def initialize
      @storage_path = ENV.fetch("LOCAL_STORAGE_PATH", Rails.root.join("storage"))
      FileUtils.mkdir_p(@storage_path)
    end

    def upload(file, options = {})
      filename = options[:filename] || generate_filename(file)
      folder = options[:folder] || "uploads"
      path = File.join(@storage_path, folder, filename)

      FileUtils.mkdir_p(File.dirname(path))

      if file.is_a?(String)
        FileUtils.cp(file, path)
      else
        File.open(path, "wb") do |f|
          f.write(file.read)
        end
      end

      {
        public_id: File.join(folder, filename),
        url: "/storage/#{folder}/#{filename}",
        bytes: File.size(path),
        format: File.extname(filename).delete("."),
        created_at: Time.now,
        original_filename: filename,
        resource_type: options[:resource_type] || "auto"
      }
    rescue => e
      Rails.logger.error("[LocalStorage] Upload Error: #{e.message}")
      raise UploadError, e.message
    end

    def delete(identifier, options = {})
      path = get_full_path(identifier, options)

      if File.exist?(path)
        FileUtils.rm(path)
        true
      else
        raise NotFoundError, "File not found: #{identifier}"
      end
    rescue => e
      Rails.logger.error("[LocalStorage] Delete Error: #{e.message}")
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
        public_id: destination,
        url: "/storage/#{destination}"
      }
    rescue => e
      Rails.logger.error("[LocalStorage] Move Error: #{e.message}")
      raise Error, e.message
    end

    def copy(source, destination, options = {})
      source_path = get_full_path(source, options)
      dest_path = get_full_path(destination, options)

      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(source_path, dest_path)

      {
        public_id: destination,
        url: "/storage/#{destination}"
      }
    rescue => e
      Rails.logger.error("[LocalStorage] Copy Error: #{e.message}")
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
          public_id: relative_path,
          url: "/storage/#{relative_path}",
          bytes: File.size(file),
          format: File.extname(file).delete("."),
          created_at: File.ctime(file),
          resource_type: options[:resource_type] || "auto"
        }
      end
    end

    private

    def get_full_path(identifier, options = {})
      if identifier.start_with?(@storage_path.to_s)
        identifier
      else
        folder = options[:folder] || "uploads"
        File.join(@storage_path, folder, identifier)
      end
    end

    def generate_filename(file)
      basename = file.is_a?(String) ? File.basename(file, ".*") : File.basename(file.original_filename, ".*")
      extension = file.is_a?(String) ? File.extname(file) : File.extname(file.original_filename)
      "#{basename}_#{Time.now.to_i}#{extension}"
    end
  end
end
