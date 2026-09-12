# app/services/media_service/svg_to_png.rb

module MediaService
  class SvgToPng
    Result = Struct.new(:file, :filename, :tmpdir, keyword_init: true) do
      def converted?
        tmpdir.present?
      end
    end

    def self.prepare(file)
      return Result.new(file: file, filename: file.original_filename, tmpdir: nil) unless svg?(file)

      tmpdir = nil
      tmpdir = Dir.mktmpdir("svg_to_png")
      input_path = File.join(tmpdir, "input.svg")
      FileUtils.cp(source_path(file), input_path)
      png_path = ImageConversion.encode_png(input_path)
      filename = "#{File.basename(file.original_filename.to_s, '.*').presence || 'asset'}.png"
      Result.new(file: png_path, filename: filename, tmpdir: tmpdir)
    rescue StandardError
      FileUtils.rm_rf(tmpdir) if tmpdir
      raise
    end

    def self.cleanup(result)
      FileUtils.rm_rf(result.tmpdir) if result&.tmpdir.present?
    end

    def self.svg?(file)
      filename = file.respond_to?(:original_filename) ? file.original_filename.to_s : file.to_s
      ext = File.extname(filename).delete(".").downcase
      return true if ext == MediaConstants::IMAGE_EXT_SVG

      file.respond_to?(:content_type) && file.content_type.to_s.include?("svg")
    end

    def self.source_path(file)
      if file.respond_to?(:tempfile)
        file.tempfile.rewind
        file.tempfile.path
      elsif file.respond_to?(:path)
        file.path
      else
        file.to_s
      end
    end
    private_class_method :source_path
  end
end
