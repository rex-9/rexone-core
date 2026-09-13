require "rails_helper"

RSpec.describe AssetConstants do
  describe AssetConstants::AssetFormat do
    it "selects upload limits by application media format" do
      expect(described_class.upload_limit_mb("mp4")).to eq(MediaConstants::MAX_VIDEO_SIZE_MB)
      expect(described_class.upload_limit_mb("wav")).to eq(MediaConstants::MAX_AUDIO_SIZE_MB)
      expect(described_class.upload_limit_mb("amr")).to eq(MediaConstants::MAX_AUDIO_SIZE_MB)
      expect(described_class.upload_limit_mb("svg")).to eq(MediaConstants::MAX_IMAGE_SIZE_MB)
      expect(described_class.upload_limit_mb("srt")).to eq(MediaConstants::MAX_OTHER_SIZE_MB)
      expect(described_class.upload_limit_mb("bin")).to eq(MediaConstants::MAX_OTHER_SIZE_MB)
    end
  end

  describe AssetConstants::AssetName do
    it "replaces an existing storage-key extension" do
      expect(described_class.with_extension("dev/user/id/audio.wav", "m4a"))
        .to eq("dev/user/id/audio.m4a")
    end

    it "adds an extension when the provider key has none" do
      expect(described_class.with_extension("admin/general_audio", "m4a"))
        .to eq("admin/general_audio.m4a")
    end
  end
end
