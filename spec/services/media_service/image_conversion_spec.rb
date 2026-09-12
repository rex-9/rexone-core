require "rails_helper"

RSpec.describe MediaService::ImageConversion do
  let(:input_path) { "/tmp/input_image.svg" }
  let(:output_path) { "/tmp/output_image.png" }

  describe "#encode_png" do
    it "renders SVG to PNG with rsvg-convert at max image size" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      allow(File).to receive(:exist?).with(output_path).and_return(true)
      allow(File).to receive(:zero?).with(output_path).and_return(false)

      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return([ "", "", status ])

      result = described_class.encode_png(input_path, output_path: output_path)

      expect(result).to eq(output_path)
      expect(Open3).to have_received(:capture3).with(
        "rsvg-convert",
        "-f", "png",
        "--keep-aspect-ratio",
        "-w", MediaConstants::IMAGE_MAX_WIDTH.to_s,
        "-h", MediaConstants::IMAGE_MAX_HEIGHT.to_s,
        "-o", output_path,
        input_path
      )
    end

    it "raises ConversionError when rsvg-convert fails" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return([ "", "bad svg", status ])

      expect do
        described_class.encode_png(input_path, output_path: output_path)
      end.to raise_error(MediaService::ConversionError, /Image conversion failed: bad svg/)
    end

    it "raises ConversionError when rsvg-convert is missing" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect do
        described_class.encode_png(input_path, output_path: output_path)
      end.to raise_error(MediaService::ConversionError, /rsvg-convert is not installed/)
    end
  end
end
