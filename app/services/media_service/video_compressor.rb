# app/services/media_service/video_compressor.rb

require "open3"

module MediaService
  class VideoCompressor
    LOG_PREFIX = "[VideoCompressor]".freeze

    # Compresses a video file and returns the output path.
    # @param input_path [String] path to the source video file
    # @param output_path [String] optional path for the compressed output (defaults to input_path with _compressed suffix)
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
      max_w = MediaConstants::VIDEO_MAX_WIDTH
      max_h = MediaConstants::VIDEO_MAX_HEIGHT

      [
        "ffmpeg",
        "-i", @input_path,
        "-vcodec", MediaConstants::VIDEO_CODEC,
        "-crf", MediaConstants::VIDEO_CRF.to_s,
        "-preset", MediaConstants::VIDEO_PRESET,
        "-maxrate", MediaConstants::VIDEO_MAX_BITRATE,
        "-bufsize", MediaConstants::VIDEO_BUFFER_SIZE,
        "-vf", "scale='min(#{max_w},iw)':'min(#{max_h},ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2",
        "-pix_fmt", "yuv420p",
        "-acodec", MediaConstants::VIDEO_AUDIO_CODEC,
        "-b:a", MediaConstants::VIDEO_AUDIO_BITRATE,
        "-movflags", "+faststart",
        "-y",  # overwrite output
        @output_path
      ]
    end

    def generate_output_path(input_path)
      dir = File.dirname(input_path)
      ext = File.extname(input_path)
      base = File.basename(input_path, ext)
      File.join(dir, "#{base}_compressed#{ext}")
    end
  end
end
