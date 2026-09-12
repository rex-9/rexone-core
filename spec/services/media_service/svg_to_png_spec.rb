require "rails_helper"

RSpec.describe MediaService::SvgToPng do
  describe ".prepare" do
    it "returns the original upload when the file is not an SVG" do
      file = fixture_file_upload("avatar.png", "image/png")

      result = described_class.prepare(file)

      expect(result.converted?).to be(false)
      expect(result.file).to eq(file)
      expect(result.filename).to eq("avatar.png")
      expect(result.tmpdir).to be_nil
    end

    it "converts SVG to PNG and reports a converted result" do
      file = fixture_file_upload("icon.svg", "image/svg+xml")
      allow(MediaService::ImageConversion).to receive(:encode_png) do |input_path|
        png_path = input_path.sub(/\.svg\z/, ".png")
        File.write(png_path, "fake-png")
        png_path
      end

      result = described_class.prepare(file)

      expect(result.converted?).to be(true)
      expect(result.filename).to eq("icon.png")
      expect(File.exist?(result.file)).to be(true)
      expect(MediaService::ImageConversion).to have_received(:encode_png)
      described_class.cleanup(result)
      expect(File.exist?(result.file)).to be(false)
    end

    it "treats image/svg+xml content type as SVG even without an svg extension" do
      file = fixture_file_upload("icon.svg", "image/svg+xml")
      allow(file).to receive(:original_filename).and_return("logo")
      allow(MediaService::ImageConversion).to receive(:encode_png) do |input_path|
        png_path = File.join(File.dirname(input_path), "input.png")
        File.write(png_path, "fake-png")
        png_path
      end

      result = described_class.prepare(file)

      expect(result.converted?).to be(true)
      expect(result.filename).to eq("logo.png")
      described_class.cleanup(result)
    end

    it "removes the temp directory when conversion fails" do
      file = fixture_file_upload("icon.svg", "image/svg+xml")
      captured_tmpdir = nil
      allow(Dir).to receive(:mktmpdir).and_wrap_original do |method, *args|
        captured_tmpdir = method.call(*args)
      end
      allow(MediaService::ImageConversion).to receive(:encode_png)
        .and_raise(MediaService::ConversionError, "Image conversion failed: svg")

      expect { described_class.prepare(file) }.to raise_error(MediaService::ConversionError)
      expect(captured_tmpdir).to be_present
      expect(Dir.exist?(captured_tmpdir)).to be(false)
    end
  end
end
