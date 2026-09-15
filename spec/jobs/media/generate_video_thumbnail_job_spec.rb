require "rails_helper"

RSpec.describe Media::GenerateVideoThumbnailJob, type: :job do
  it "generates, stores, and broadcasts a canonical thumbnail asset" do
    creator = create(:user)
    video = create(
      :asset,
      creator: creator,
      format: AssetConstants::AssetFormat::VIDEO,
      extension: "mp4",
      storage_key: "dev/admin/video_demo.mp4"
    )
    allow(StorageService::Client).to receive(:download)
    allow(MediaService::VideoThumbnailer).to receive(:generate)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "dev/admin/thumbnail_#{video.id}.webp",
      url: "https://assets.example.com/thumbnail.webp",
      bytes: 512,
      format: MediaConstants::IMAGE_EXT_WEBP
    )
    expect do
      described_class.perform_now(asset_id: video.id)
    end.to change(Asset, :count).by(1)

    thumbnail = video.reload.thumbnail
    expect(thumbnail).to have_attributes(
      type: AssetConstants::AssetType::THUMBNAIL,
      format: AssetConstants::AssetFormat::IMAGE,
      storage_key: "dev/admin/thumbnail_#{video.id}.webp",
      size_bytes: 512,
      assetable: video.assetable
    )
    notification = creator.user_notifications.find_by!(operation_type: NotificationConstants::OperationType::VIDEO_THUMBNAIL)
    expect(notification).to have_attributes(
      message: I18n.t("admin.asset.thumbnail_generated", name: video.name),
      operation_status: NotificationConstants::OperationStatus::COMPLETED,
      link: "/admin/assets/#{video.id}"
    )
    expect(notification.metadata).to include(
      "type" => MediaConstants::SocketEvent::ASSET_THUMBNAIL_GENERATED,
      "asset_id" => video.id
    )
    expect(video.reload.status).to eq(MediaConstants::Status::READY)
  end

  it "does not create another thumbnail when one already exists" do
    video = create(:asset, format: AssetConstants::AssetFormat::VIDEO, extension: "mp4")
    create(:asset, type: AssetConstants::AssetType::THUMBNAIL, parent_asset: video)

    expect do
      described_class.perform_now(asset_id: video.id)
    end.not_to change(Asset, :count)
  end

  it "uses the shared per-asset media-processing concurrency key" do
    video = create(:asset, format: AssetConstants::AssetFormat::VIDEO, extension: "mp4")

    expect(described_class.concurrency_key.call(asset_id: video.id)).to eq(
      MediaConstants::Processing.concurrency_key(video.id)
    )
    expect(Media::CompressMediaJob.concurrency_key.call(asset_id: video.id)).to eq(
      MediaConstants::Processing.concurrency_key(video.id)
    )
  end
end
