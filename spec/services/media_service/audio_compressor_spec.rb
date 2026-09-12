require "rails_helper"

RSpec.describe MediaService::AudioCompressor do
  let(:input_path) { "/tmp/input_audio.mp3" }
  let(:output_path) { "/tmp/output_audio.mp3" }

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

    it "executes FFmpeg with libmp3lame for MP3 input" do
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
        "-vn",
        "-acodec", "libmp3lame",
        "-b:a", "128k",
        "-ar", "44100",
        "-ac", "2",
        "-y",
        output_path
      )
    end

    it "remuxes WAV to M4A with AAC and faststart" do
      wav_input = "/tmp/input_audio.wav"
      m4a_output = "/tmp/output_audio.m4a"

      allow(File).to receive(:exist?).with(wav_input).and_return(true)
      allow(File).to receive(:zero?).with(wav_input).and_return(false)
      allow(File).to receive(:size).with(wav_input).and_return(10_000)

      allow(File).to receive(:exist?).with(m4a_output).and_return(true)
      allow(File).to receive(:zero?).with(m4a_output).and_return(false)
      allow(File).to receive(:size).with(m4a_output).and_return(4_000)

      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return([ "", "", status ])

      result = described_class.compress(wav_input, output_path: m4a_output)

      expect(result).to eq(m4a_output)
      expect(Open3).to have_received(:capture3).with(
        "ffmpeg",
        "-i", wav_input,
        "-vn",
        "-acodec", "aac",
        "-b:a", "128k",
        "-ar", "44100",
        "-ac", "2",
        "-movflags", "+faststart",
        "-y",
        m4a_output
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
