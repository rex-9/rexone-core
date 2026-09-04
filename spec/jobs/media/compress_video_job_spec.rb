require "rails_helper"

RSpec.describe Media::CompressVideoJob, type: :job do
  let(:asset) { create(:asset, status: "pending", extension: "mp4", url: "https://example.com/original.mp4", size_bytes: 20_000_000) }

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  before do
    allow_any_instance_of(described_class).to receive(:download_from_storage).and_return("/tmp/fake_input.mp4")
    allow(MediaService::VideoCompressor).to receive(:compress).and_return("/tmp/fake_compressed.mp4")
    allow(File).to receive(:size).with("/tmp/fake_input.mp4").and_return(20_000_000)
    allow(File).to receive(:size).with("/tmp/fake_compressed.mp4").and_return(8_000_000)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: asset.storage_key,
      url: "https://example.com/compressed.mp4",
      bytes: 8_000_000,
      format: "mp4",
      resource_type: "video"
    )
  end

  it "processes pending video asset, re-uploads compressed file, and marks ready" do
    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.status).to eq("ready")
    expect(asset.size_bytes).to eq(8_000_000)
    expect(asset.url).to eq("https://example.com/compressed.mp4")
    expect(MediaService::VideoCompressor).to have_received(:compress).with("/tmp/fake_input.mp4")
    expect(StorageService::Client).to have_received(:upload).with(
      "/tmp/fake_compressed.mp4",
      hash_including(storage_key: asset.storage_key, overwrite: true, resource_type: "video")
    )
  end

  it "keeps original file and marks optimal immediately if compressed size is not smaller than original" do
    allow(File).to receive(:size).with("/tmp/fake_compressed.mp4").and_return(20_000_000)

    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.status).to eq("optimal")
    expect(asset.size_bytes).to eq(20_000_000)
    expect(StorageService::Client).not_to have_received(:upload)
    expect(asset.compression_count).to eq(MediaConstants::MAX_COMPRESSION_PASSES)
  end

  it "marks asset as optimal once it reaches MAX_COMPRESSION_PASSES (2 passes)" do
    # Pass 1 (on upload)
    described_class.perform_now(asset_id: asset.id)
    expect(asset.reload.status).to eq("ready")
    expect(asset.compression_count).to eq(1)

    # Pass 2 (admin manual compress)
    described_class.perform_now(asset_id: asset.id)
    expect(asset.reload.status).to eq("optimal")
    expect(asset.max_compressed?).to be true
  end

  it "skips processing if asset is already optimal" do
    asset.update!(status: "optimal")

    described_class.perform_now(asset_id: asset.id)

    expect(MediaService::VideoCompressor).not_to have_received(:compress)
  end

  it "broadcasts notification to user who created the asset" do
    user = create(:user)
    asset.update!(created_by_id: user.id)
    allow(SocketService::Client).to receive(:broadcast)

    described_class.perform_now(asset_id: asset.id)

    expect(SocketService::Client).to have_received(:broadcast).with(
      user_id: user.id,
      message: anything,
      data: hash_including(type: MediaConstants::SocketEvent::ASSET_COMPRESSED, status: "ready")
    )
  end

  it "marks asset as failed when compression fails" do
    allow(MediaService::VideoCompressor).to receive(:compress).and_raise(MediaService::CompressionError, "ffmpeg killed")

    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.status).to eq("failed")
  end
end
