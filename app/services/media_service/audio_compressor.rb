# app/services/media_service/audio_compressor.rb

require "open3"

module MediaService
  class AudioCompressor
    LOG_PREFIX = "[AudioCompressor]".freeze

    # Compresses an audio file and returns the output path.
    # @param input_path [String] path to the source audio file
    # @param output_path [String] optional path for the compressed output
    # @return [String] path to the compressed file
    # @raise [MediaService::CompressionError] if FFmpeg fails
    def self.compress(input_path, output_path: nil)
      new(input_path, output_path: output_path).compress
    end

    def initialize(input_path, output_path: nil)
      @input_path = input_path
      @output_path = output_path || generate_output_path(input_path)
    end

    def compress
      validate_input!
      run_ffmpeg!
      validate_output!
      @output_path
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

    def run_ffmpeg!
      cmd = build_ffmpeg_command
      Rails.logger.info("#{LOG_PREFIX} Running: #{cmd.join(' ')}")

      _stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        Rails.logger.error("#{LOG_PREFIX} FFmpeg failed (exit #{status.exitstatus}): #{stderr.last(500)}")
        raise CompressionError, "FFmpeg exited with status #{status.exitstatus}: #{stderr.last(200)}"
      end

      Rails.logger.info("#{LOG_PREFIX} Compression complete: #{File.size(@input_path)} -> #{File.size(@output_path)} bytes")
    end

    def build_ffmpeg_command
      cmd = [
        "ffmpeg",
        "-i", @input_path,
        "-vn",
        "-acodec", audio_codec,
        "-b:a", MediaConstants::AUDIO_BITRATE,
        "-ar", "44100",
        "-ac", "2"
      ]
      cmd += [ "-movflags", "+faststart" ] if m4a_output?
      cmd + [ "-y", @output_path ]
    end

    def audio_codec
      input_ext == MediaConstants::AUDIO_EXT_MP3 ? "libmp3lame" : MediaConstants::AUDIO_CODEC
    end

    def input_ext
      File.extname(@input_path).delete(".").downcase
    end

    def m4a_output?
      File.extname(@output_path).delete(".").downcase == MediaConstants::AUDIO_EXT_M4A
    end

    def generate_output_path(input_path)
      dir = File.dirname(input_path)
      ext = File.extname(input_path)
      base = File.basename(input_path, ext)
      out_ext = if MediaConstants::AAC_INCOMPATIBLE_AUDIO_EXTENSIONS.include?(input_ext)
                  ".#{MediaConstants::AUDIO_EXT_M4A}"
      else
                  ext
      end
      File.join(dir, "#{base}_compressed#{out_ext}")
    end
  end
end
