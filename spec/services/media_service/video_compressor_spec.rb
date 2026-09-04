require "rails_helper"

RSpec.describe MediaService::VideoCompressor do
  let(:input_path) { "/tmp/input_video.mp4" }
  let(:output_path) { "/tmp/output_video.mp4" }

  describe "#compress" do
    it "raises CompressionError if input file is missing" do
      allow(File).to receive(:exist?).with(input_path).and_return(false)

      expect do
        described_class.compress(input_path)
      end.to raise_error(MediaService::CompressionError, /Input file not found/)
    end

    it "raises CompressionError if input file is empty" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(true)

      expect do
        described_class.compress(input_path)
      end.to raise_error(MediaService::CompressionError, /Input file is empty/)
    end

    it "executes FFmpeg and validates the generated output" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      allow(File).to receive(:size).with(input_path).and_return(10_000)

      allow(File).to receive(:exist?).with(output_path).and_return(true)
      allow(File).to receive(:zero?).with(output_path).and_return(false)
      allow(File).to receive(:size).with(output_path).and_return(4_000)

      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return([ "", "", status ])

      result = described_class.compress(input_path, output_path: output_path)

      expect(result).to eq(output_path)
      expect(Open3).to have_received(:capture3).with(
        "ffmpeg",
        "-i", input_path,
        "-vcodec", "libx264",
        "-crf", "23",
        "-preset", "medium",
        "-maxrate", "5M",
        "-bufsize", "10M",
        "-vf", "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2",
        "-pix_fmt", "yuv420p",
        "-acodec", "aac",
        "-b:a", "128k",
        "-movflags", "+faststart",
        "-y",
        output_path
      )
    end

    it "raises CompressionError when FFmpeg command fails" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)

      status = instance_double(Process::Status, success?: false, exitstatus: 1)
      allow(Open3).to receive(:capture3).and_return([ "", "Invalid data found", status ])

      expect do
        described_class.compress(input_path, output_path: output_path)
      end.to raise_error(MediaService::CompressionError, /FFmpeg exited with status 1/)
    end
  end
end
