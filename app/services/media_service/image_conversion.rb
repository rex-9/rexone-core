# app/services/media_service/image_conversion.rb

require "open3"

module MediaService
  class ImageConversion
    LOG_PREFIX = "[ImageConversion]".freeze
    RSVG_CONVERT = "rsvg-convert".freeze

    # Render an SVG to PNG for storage. Debian libvips in Docker has no SVG loader,
    # and rsvg-convert cannot write WebP, so PNG is the stored format.
    # @param input_path [String] path to the source SVG
    # @param output_path [String] optional path for the PNG output
    # @return [String] path to the converted file
    # @raise [MediaService::ConversionError] if conversion fails
    def self.encode_png(input_path, output_path: nil)
      output_path ||= begin
        dir = File.dirname(input_path)
        base = File.basename(input_path, File.extname(input_path))
        File.join(dir, "#{base}.png")
      end
      new(input_path, output_path: output_path).encode_png
    end

    def initialize(input_path, output_path:)
      @input_path = input_path
      @output_path = output_path
    end

    def encode_png
      validate_input!
      _stdout, stderr, status = Open3.capture3(
        RSVG_CONVERT,
        "-f", "png",
        "--keep-aspect-ratio",
        "-w", MediaConstants::IMAGE_MAX_WIDTH.to_s,
        "-h", MediaConstants::IMAGE_MAX_HEIGHT.to_s,
        "-o", @output_path,
        @input_path
      )
      unless status.success?
        detail = stderr.to_s.last(200).presence || "rsvg-convert failed"
        raise ConversionError, "Image conversion failed: #{detail}"
      end

      validate_output!
      @output_path
    rescue Errno::ENOENT
      raise ConversionError, "Image conversion failed: rsvg-convert is not installed"
    end

    private

    def validate_input!
      raise ConversionError, "Input file not found: #{@input_path}" unless File.exist?(@input_path)
      raise ConversionError, "Input file is empty: #{@input_path}" if File.zero?(@input_path)
    end

    def validate_output!
      raise ConversionError, "Output file not created: #{@output_path}" unless File.exist?(@output_path)
      raise ConversionError, "Output file is empty: #{@output_path}" if File.zero?(@output_path)
    end
  end
end
