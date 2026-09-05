# app/services/media_service/image_compressor.rb

module MediaService
  class ImageCompressor
    LOG_PREFIX = "[ImageCompressor]".freeze

    # Compresses an image file and returns the output path.
    # @param input_path [String] path to the source image file
    # @param output_path [String] optional path for the compressed output
    # @return [String] path to the compressed file
    # @raise [MediaService::CompressionError] if compression fails
    def self.compress(input_path, output_path: nil)
      new(input_path, output_path: output_path).compress
    end

    def initialize(input_path, output_path: nil)
      @input_path = input_path
      @output_path = output_path || generate_output_path(input_path)
    end

    def compress
      validate_input!

      image = Vips::Image.new_from_file(@input_path)
      image = resize_if_needed(image)

      ext = File.extname(@input_path).delete(".").downcase
      save_compressed(image, ext)

      validate_output!

      original_size = File.size(@input_path)
      compressed_size = File.size(@output_path)

      if compressed_size >= original_size
        Rails.logger.info("#{LOG_PREFIX} Compressed file (#{compressed_size} bytes) >= original (#{original_size} bytes). Preserving original file.")
        FileUtils.cp(@input_path, @output_path)
        compressed_size = original_size
      else
        Rails.logger.info("#{LOG_PREFIX} Compression complete: #{original_size} -> #{compressed_size} bytes (#{reduction_percent(original_size, compressed_size)}% reduction)")
      end

      @output_path
    rescue Vips::Error => e
      Rails.logger.error("#{LOG_PREFIX} Vips error: #{e.message}")
      raise CompressionError, "Image compression failed: #{e.message}"
    end

    private

    def validate_input!
      raise CompressionError, "Input file not found: #{@input_path}" unless File.exist?(@input_path)
      raise CompressionError, "Input file is empty: #{@input_path}" if File.zero?(@input_path)
    end

    def validate_output!
      raise CompressionError, "Output file not created: #{@output_path}" unless File.exist?(@output_path)
      raise CompressionError, "Output file is empty: #{@output_path}" if File.zero?(@output_path)
    end

    def resize_if_needed(image)
      max_w = MediaConstants::IMAGE_MAX_WIDTH
      max_h = MediaConstants::IMAGE_MAX_HEIGHT

      if image.width > max_w || image.height > max_h
        scale = [ max_w.to_f / image.width, max_h.to_f / image.height ].min
        image = image.resize(scale)
        Rails.logger.info("#{LOG_PREFIX} Resized to #{image.width}x#{image.height}")
      end

      image
    end

    def save_compressed(image, ext)
      case ext
      when MediaConstants::IMAGE_EXT_JPG, MediaConstants::IMAGE_EXT_JPEG
        image.jpegsave(@output_path, Q: MediaConstants::IMAGE_JPEG_QUALITY, optimize_coding: true, strip: true)
      when MediaConstants::IMAGE_EXT_PNG
        image.pngsave(@output_path, palette: true, Q: MediaConstants::IMAGE_PNG_QUALITY, compression: MediaConstants::IMAGE_PNG_COMPRESSION, strip: true)
      when MediaConstants::IMAGE_EXT_WEBP
        image.webpsave(@output_path, Q: MediaConstants::IMAGE_WEBP_QUALITY, effort: 4, strip: true)
      else
        # For unsupported formats, just copy
        FileUtils.cp(@input_path, @output_path)
      end
    end

    def generate_output_path(input_path)
      dir = File.dirname(input_path)
      ext = File.extname(input_path)
      base = File.basename(input_path, ext)
      File.join(dir, "#{base}_compressed#{ext}")
    end

    def reduction_percent(original, compressed)
      return 0 if original.zero?
      ((1.0 - compressed.to_f / original) * 100).round(1)
    end
  end
end
