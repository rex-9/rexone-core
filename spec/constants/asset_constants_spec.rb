require "rails_helper"

RSpec.describe AssetConstants do
  describe AssetConstants::AssetFormat do
    it "selects upload limits by application media format" do
      expect(described_class.upload_limit_mb("mp4")).to eq(MediaConstants::MAX_VIDEO_SIZE_MB)
      expect(described_class.upload_limit_mb("wav")).to eq(MediaConstants::MAX_AUDIO_SIZE_MB)
      expect(described_class.upload_limit_mb("amr")).to eq(MediaConstants::MAX_AUDIO_SIZE_MB)
      expect(described_class.upload_limit_mb("svg")).to eq(MediaConstants::MAX_IMAGE_SIZE_MB)
      expect(described_class.upload_limit_mb("zip")).to eq(MediaConstants::MAX_OTHER_SIZE_MB)
      expect(described_class.upload_limit_mb("srt")).to eq(MediaConstants::MAX_OTHER_SIZE_MB)
      expect(described_class.upload_limit_mb("bin")).to eq(MediaConstants::MAX_OTHER_SIZE_MB)
    end

    it "classifies zip files as zip format with raw storage" do
      expect(described_class.from_extension("zip")).to eq(described_class::ZIP)
      expect(described_class.storage_resource_type("zip")).to eq("raw")
    end
  end

  describe "StoragePartition and ENVIRONMENT_PREFIXES" do
    it "defines standard environment partitions as constants" do
      expect(AssetConstants::StoragePartition::DEV).to eq("dev")
      expect(AssetConstants::StoragePartition::UAT).to eq("uat")
      expect(AssetConstants::StoragePartition::PROD).to eq("prod")
      expect(AssetConstants::STORAGE_PARTITIONS).to eq(%w[dev uat prod])
      expect(AssetConstants::ENVIRONMENT_PREFIXES).to eq(%w[dev uat prod])
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

    describe ".rename_type" do
      it "replaces old type prefix while strictly preserving directory path in dev/admin" do
        expect(described_class.rename_type("dev/admin/avatar_sample_123.png", "thumbnail", "avatar"))
          .to eq("dev/admin/thumbnail_sample_123.png")
      end

      it "replaces old type prefix while strictly preserving directory path in uat/admin" do
        expect(described_class.rename_type("uat/admin/general_doc_456.pdf", "attachment", "general"))
          .to eq("uat/admin/attachment_doc_456.pdf")
      end

      it "replaces old type prefix while strictly preserving user partition path" do
        expect(described_class.rename_type("dev/user/uuid-999/avatar_pic_1.jpg", "thumbnail", "avatar"))
          .to eq("dev/user/uuid-999/thumbnail_pic_1.jpg")
      end

      it "replaces type prefix when no directory is present" do
        expect(described_class.rename_type("avatar_pic_1.jpg", "thumbnail", "avatar"))
          .to eq("thumbnail_pic_1.jpg")
      end

      it "infers old type from known AssetType when old_type argument is omitted" do
        expect(described_class.rename_type("dev/admin/general_asset_789.png", "avatar"))
          .to eq("dev/admin/avatar_asset_789.png")
      end

      it "returns original key if key or new_type is blank" do
        expect(described_class.rename_type("", "thumbnail")).to eq("")
        expect(described_class.rename_type("dev/admin/avatar_1.png", "")).to eq("dev/admin/avatar_1.png")
      end
    end
  end
end
