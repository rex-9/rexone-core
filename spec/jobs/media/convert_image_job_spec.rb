require "rails_helper"

RSpec.describe Media::ConvertImageJob, type: :job do
  let(:asset) do
    create(
      :asset,
      name: "admin/general_icon.svg",
      storage_key: "admin/general_icon.svg",
      url: "https://example.com/general_icon.svg",
      extension: "svg",
      format: "image",
      status: "pending"
    )
  end

  before do
    allow_any_instance_of(described_class).to receive(:download_from_storage).and_return("/tmp/input.svg")
    allow(MediaService::ImageConversion).to receive(:encode_png).and_return("/tmp/input.png")
    allow(File).to receive(:size).with("/tmp/input.png").and_return(512)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "admin/general_icon.png",
      url: "https://example.com/general_icon.png",
      bytes: 512,
      format: "png",
      resource_type: "image"
    )
    allow(StorageService::Client).to receive(:delete)
    allow(Media::CompressMediaJob).to receive(:perform_later)
  end

  it "converts an SVG in the media queue, persists the PNG contract, and removes the SVG object" do
    described_class.perform_now(asset_id: asset.id)

    expect(asset.reload).to have_attributes(
      name: "admin/general_icon.png",
      storage_key: "admin/general_icon.png",
      url: "https://example.com/general_icon.png",
      extension: "png",
      format: "image",
      size_bytes: 512,
      status: "pending"
    )
    expect(StorageService::Client).to have_received(:upload).with(
      "/tmp/input.png",
      hash_including(storage_key: "admin/general_icon.png", resource_type: "image")
    )
    expect(StorageService::Client).to have_received(:delete).with("admin/general_icon.svg", resource_type: "image")
    expect(Media::CompressMediaJob).to have_received(:perform_later).with(
      asset_id: asset.id,
      notification_user_id: asset.created_by_id,
      operation_id: start_with("asset_compression:#{asset.id}:")
    )
  end

  it "does not process a non-SVG asset" do
    asset.update!(extension: "png", status: "ready")

    described_class.perform_now(asset_id: asset.id)

    expect(MediaService::ImageConversion).not_to have_received(:encode_png)
  end
end
