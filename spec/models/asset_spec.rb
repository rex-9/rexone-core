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
  end

  it "prefers an uploaded profile picture over a Google picture" do
    user = create(:user)
    create(:asset, source: "google", storage_key: nil, resource_model: "user", resource_id: user.id, type: "avatar", url: "https://example.com/google.jpg")
    uploaded = create(:asset, resource_model: "user", resource_id: user.id, type: "avatar", url: "https://example.com/upload.jpg")
    expect(user.get_profile_pic_url).to eq(uploaded.url)
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

  it "refreshes uploaded URLs and preserves the old URL when storage fails" do
    asset = create(:asset)
    allow(StorageService::Client).to receive(:url).and_return("https://example.com/refreshed.jpg")
    expect(asset.refresh_url).to be(true)
    expect(asset.reload.url).to eq("https://example.com/refreshed.jpg")

    allow(StorageService::Client).to receive(:url).and_raise(StorageService::Error, "offline")
    expect(asset.refresh_url).to be(false)
    expect(asset.reload.url).to eq("https://example.com/refreshed.jpg")
  end
end
