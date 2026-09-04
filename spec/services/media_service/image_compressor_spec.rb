require "rails_helper"

RSpec.describe MediaService::ImageCompressor do
  let(:input_path) { "/tmp/input_image.png" }
  let(:output_path) { "/tmp/output_image.png" }

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

    it "loads image via Vips, resizes if larger than 1080p, and saves compressed" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      allow(File).to receive(:size).with(input_path).and_return(50_000)

      allow(File).to receive(:exist?).with(output_path).and_return(true)
      allow(File).to receive(:zero?).with(output_path).and_return(false)
      allow(File).to receive(:size).with(output_path).and_return(20_000)

      vips_image = double("Vips::Image", width: 3840, height: 2160)
      resized_image = double("Vips::Image", width: 1920, height: 1080)

      allow(Vips::Image).to receive(:new_from_file).with(input_path).and_return(vips_image)
      allow(vips_image).to receive(:resize).with(0.5).and_return(resized_image)
      allow(resized_image).to receive(:pngsave).with(output_path, palette: true, Q: MediaConstants::IMAGE_PNG_QUALITY, compression: MediaConstants::IMAGE_PNG_COMPRESSION, strip: true)

      result = described_class.compress(input_path, output_path: output_path)

      expect(result).to eq(output_path)
      expect(resized_image).to have_received(:pngsave).with(output_path, palette: true, Q: MediaConstants::IMAGE_PNG_QUALITY, compression: MediaConstants::IMAGE_PNG_COMPRESSION, strip: true)
    end

    it "copies original file if compressed size is larger than or equal to original size" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      allow(File).to receive(:size).with(input_path).and_return(20_000)

      allow(File).to receive(:exist?).with(output_path).and_return(true)
      allow(File).to receive(:zero?).with(output_path).and_return(false)
      allow(File).to receive(:size).with(output_path).and_return(25_000)

      allow(FileUtils).to receive(:cp).with(input_path, output_path)

      vips_image = double("Vips::Image", width: 800, height: 600)
      allow(Vips::Image).to receive(:new_from_file).with(input_path).and_return(vips_image)
      allow(vips_image).to receive(:pngsave).with(output_path, palette: true, Q: MediaConstants::IMAGE_PNG_QUALITY, compression: MediaConstants::IMAGE_PNG_COMPRESSION, strip: true)

      result = described_class.compress(input_path, output_path: output_path)

      expect(result).to eq(output_path)
      expect(FileUtils).to have_received(:cp).with(input_path, output_path)
    end

    it "raises CompressionError when Vips encounters an error" do
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(File).to receive(:zero?).with(input_path).and_return(false)
      allow(Vips::Image).to receive(:new_from_file).with(input_path).and_raise(Vips::Error, "Unsupported file format")

      expect do
        described_class.compress(input_path, output_path: output_path)
      end.to raise_error(MediaService::CompressionError, /Image compression failed: Unsupported file format/)
    end
  end
end
