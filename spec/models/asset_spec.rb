require "rails_helper"

RSpec.describe Asset, type: :model do
  it "accepts a complete uploaded asset" do
    expect(build(:asset)).to be_valid
  end

  it "requires valid HTTP URLs and supported metadata" do
    expect(build(:asset, url: "testing.com")).not_to be_valid
    expect(build(:asset, type: "invalid_type")).not_to be_valid
    expect(build(:asset, format: "archive")).not_to be_valid
    expect(build(:asset, source: "unknown")).not_to be_valid
    expect(build(:asset, size_bytes: -1)).not_to be_valid
    expect(build(:asset, duration_secs: -5)).not_to be_valid
  end

  it "requires storage_key only for uploaded assets" do
    expect(build(:asset, storage_key: nil)).not_to be_valid
    expect(build(:asset, source: "google", storage_key: nil)).to be_valid
  end

  it "infers extension and format from the URL and keeps unclassified as nil" do
    asset = build(:asset, url: "https://example.com/report.pdf", format: nil)
    asset.validate
    expect(asset).to have_attributes(extension: "pdf", format: "doc")

    audio_asset = build(:asset, url: "https://example.com/meditation.mp3", format: nil)
    audio_asset.validate
    expect(audio_asset).to have_attributes(extension: "mp3", format: "audio")

    unclassified = build(:asset, url: "https://example.com/archive.bin", format: nil)
    unclassified.validate
    expect(unclassified.format).to be_nil
    expect(unclassified.extension).to eq("bin")

    google_avatar = build(:asset, source: "google", storage_key: nil, type: "avatar", url: "https://lh3.googleusercontent.com/a/ACg8ocIHfd-mGmXDQx6BD6yEsOVzIi0BaV7GKqzL9XDRTWQNK7pAFfA=s96-c", format: nil, extension: nil)
    google_avatar.validate
    expect(google_avatar).to have_attributes(extension: nil, format: "image")
  end

  it "resolves a user's single profile avatar" do
    user = create(:user)
    avatar = create(:asset, assetable_type: "User", assetable_id: user.id, type: "avatar", url: "https://example.com/avatar.jpg")
    expect(user.get_avatar_url).to eq(avatar.url)
  end

  it "queues storage deletion after an uploaded record commits" do
    asset = create(:asset)
    allow(StorageService::Client).to receive(:delete_later)

    asset.destroy!

    expect(StorageService::Client).to have_received(:delete_later).with(
      asset.storage_key,
      resource_type: "image"
    )
  end

  it "does not queue deletion for Google assets" do
    asset = create(:asset, source: "google", storage_key: nil)
    allow(StorageService::Client).to receive(:delete_later)
    asset.destroy!
    expect(StorageService::Client).not_to have_received(:delete_later)
  end

  it "purges from storage and destroys records via Asset.purge_and_destroy_all!" do
    asset = create(:asset, storage_key: "custom/key_123")
    allow(StorageService::Client).to receive(:delete_later)

    Asset.purge_and_destroy_all!(Asset.where(id: asset.id))

    expect(StorageService::Client).to have_received(:delete_later).with(
      "custom/key_123",
      resource_type: "image"
    )
    expect(Asset.find_by(id: asset.id)).to be_nil
  end

  it "refreshes uploaded URLs and preserves the old URL when storage fails" do
    asset = create(:asset)
    allow(StorageService::Client).to receive(:url).and_return("https://example.com/refreshed.jpg")
    expect(asset.refresh_url).to be(true)
    expect(asset.reload.url).to eq("https://example.com/refreshed.jpg")

    allow(StorageService::Client).to receive(:url).and_raise(StorageService::Error, "offline")
    expect(asset.refresh_url).to be(false)
    expect(asset.reload.url).to eq("https://example.com/refreshed.jpg")
  end

  describe "status and compression lifecycle" do
    it "validates inclusion of status in MediaConstants::Status::ALL" do
      expect(build(:asset, status: "ready")).to be_valid
      expect(build(:asset, status: "pending")).to be_valid
      expect(build(:asset, status: "processing")).to be_valid
      expect(build(:asset, status: "optimal")).to be_valid
      expect(build(:asset, status: "failed")).to be_valid
      expect(build(:asset, status: "unknown_status")).not_to be_valid
    end

    it "provides status predicate helpers and transition methods" do
      asset = create(:asset, status: "pending")
      expect(asset.pending?).to be(true)
      expect(asset.processing?).to be(false)
      expect(asset.ready?).to be(false)
      expect(asset.optimal?).to be(false)
      expect(asset.failed?).to be(false)

      asset.mark_processing!
      expect(asset.reload.processing?).to be(true)

      asset.mark_ready!
      expect(asset.reload.ready?).to be(true)

      asset.mark_optimal!
      expect(asset.reload.optimal?).to be(true)

      asset.mark_failed!
      expect(asset.reload.failed?).to be(true)
    end

    it "identifies compressible formats accurately" do
      video = build(:asset, extension: "mp4")
      image = build(:asset, extension: "png")
      doc = build(:asset, extension: "pdf")
      optimal_image = build(:asset, extension: "png", status: "optimal")

      expect(video.compressible_video?).to be(true)
      expect(video.compressible_image?).to be(false)
      expect(video.compressible?).to be(true)

      expect(image.compressible_video?).to be(false)
      expect(image.compressible_image?).to be(true)
      expect(image.compressible?).to be(true)

      expect(doc.compressible?).to be(false)
      expect(optimal_image.compressible?).to be(false)
    end

    it "filters assets via ready, processing, optimal, and failed scopes" do
      ready_asset = create(:asset, status: "ready")
      proc_asset = create(:asset, status: "processing")
      opt_asset = create(:asset, status: "optimal")
      fail_asset = create(:asset, status: "failed")

      expect(described_class.ready).to include(ready_asset)
      expect(described_class.ready).not_to include(proc_asset, opt_asset, fail_asset)

      expect(described_class.processing).to include(proc_asset)
      expect(described_class.processing).not_to include(ready_asset, opt_asset, fail_asset)

      expect(described_class.optimal).to include(opt_asset)
      expect(described_class.optimal).not_to include(ready_asset, proc_asset, fail_asset)

      expect(described_class.failed).to include(fail_asset)
      expect(described_class.failed).not_to include(ready_asset, proc_asset, opt_asset)
    end
  end
end
