require "open3"

module MediaService
  class VideoThumbnailer
    LOG_PREFIX = "[VideoThumbnailer]".freeze

    def self.generate(input_path, output_path:)
      command = [
        "ffmpeg", "-ss", "1", "-i", input_path,
        "-frames:v", "1",
        "-vf", "scale='min(640,iw)':-2",
        "-quality", "80", "-y", output_path
      ]
      _stdout, stderr, status = Open3.capture3(*command)

      unless status.success? && File.exist?(output_path) && !File.zero?(output_path)
        Rails.logger.error("#{LOG_PREFIX} FFmpeg failed: #{stderr.last(500)}")
        raise Error, "Video thumbnail generation failed"
      end

      output_path
    end
  end
end
