require "rails_helper"

RSpec.describe Media::CompressAudioJob, type: :job do
  let(:asset) { create(:asset, status: "pending", extension: "mp3", format: "audio", type: "audio", url: "https://example.com/original.mp3", size_bytes: 5_000_000) }

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  before do
    allow_any_instance_of(described_class).to receive(:download_from_storage).and_return("/tmp/fake_input.mp3")
    allow(MediaService::AudioCompressor).to receive(:compress).and_return("/tmp/fake_compressed.mp3")
    allow(File).to receive(:size).with("/tmp/fake_input.mp3").and_return(5_000_000)
    allow(File).to receive(:size).with("/tmp/fake_compressed.mp3").and_return(1_500_000)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: asset.storage_key,
      url: "https://example.com/compressed.mp3",
      bytes: 1_500_000,
      format: "mp3",
      resource_type: "video"
    )
  end

  it "processes pending audio asset, re-uploads compressed file, and marks ready" do
    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.status).to eq("ready")
    expect(asset.size_bytes).to eq(1_500_000)
    expect(asset.url).to eq("https://example.com/compressed.mp3")
    expect(MediaService::AudioCompressor).to have_received(:compress).with("/tmp/fake_input.mp3")
    expect(StorageService::Client).to have_received(:upload).with(
      "/tmp/fake_compressed.mp3",
      hash_including(storage_key: asset.storage_key, overwrite: true, resource_type: "video")
    )
  end

  it "updates extension when WAV is remuxed to M4A" do
    asset.update!(extension: "wav", url: "https://example.com/original.wav")
    allow_any_instance_of(described_class).to receive(:download_from_storage).and_return("/tmp/fake_input.wav")
    allow(MediaService::AudioCompressor).to receive(:compress).and_return("/tmp/fake_compressed.m4a")
    allow(File).to receive(:size).with("/tmp/fake_input.wav").and_return(5_000_000)
    allow(File).to receive(:size).with("/tmp/fake_compressed.m4a").and_return(1_500_000)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: asset.storage_key,
      url: "https://example.com/compressed.m4a",
      bytes: 1_500_000,
      format: "m4a",
      resource_type: "video"
    )

    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.extension).to eq("m4a")
    expect(asset.format).to eq("audio")
    expect(asset.url).to eq("https://example.com/compressed.m4a")
  end

  it "keeps original file and marks optimal immediately if compressed size is not smaller than original" do
    allow(File).to receive(:size).with("/tmp/fake_compressed.mp3").and_return(5_000_000)

    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.status).to eq("optimal")
    expect(asset.size_bytes).to eq(5_000_000)
    expect(StorageService::Client).not_to have_received(:upload)
    expect(asset.compression_count).to eq(MediaConstants::MAX_COMPRESSION_PASSES)
  end

  it "marks asset as optimal once it reaches MAX_COMPRESSION_PASSES" do
    stub_const("MediaConstants::MAX_COMPRESSION_PASSES", 2)

    described_class.perform_now(asset_id: asset.id)
    expect(asset.reload.status).to eq("ready")
    expect(asset.compression_count).to eq(1)

    described_class.perform_now(asset_id: asset.id)
    expect(asset.reload.status).to eq("optimal")
    expect(asset.max_compressed?).to be true
  end

  it "skips processing if asset is already optimal" do
    asset.update!(status: "optimal")

    described_class.perform_now(asset_id: asset.id)

    expect(MediaService::AudioCompressor).not_to have_received(:compress)
  end

  it "persists a completed operation notification for the user who created the asset" do
    user = create(:user)
    asset.update!(created_by_id: user.id)

    described_class.perform_now(asset_id: asset.id)

    notification = user.user_notifications.find_by!(operation_type: NotificationConstants::OperationType::ASSET_COMPRESSION)
    expect(notification).to have_attributes(
      operation_status: NotificationConstants::OperationStatus::COMPLETED,
      link: "/admin/assets/#{asset.id}"
    )
    expect(notification.data).to include("type" => MediaConstants::SocketEvent::ASSET_COMPRESSED, "status" => "ready")
  end

  it "retries without publishing a terminal failure on the first attempt" do
    allow(MediaService::AudioCompressor).to receive(:compress).and_raise(MediaService::CompressionError, "ffmpeg killed")

    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload.status).to eq("processing")
    expect(UserNotification.where(operation_status: NotificationConstants::OperationStatus::FAILED)).to be_empty
  end
end
