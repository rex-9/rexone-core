require "rails_helper"

RSpec.describe Media::ImportRemoteImageJob, type: :job do
  it "imports a remote profile image through storage on the media queue" do
    asset = create(:asset, source: AssetConstants::AssetSource::GOOGLE, storage_key: nil, extension: nil, format: AssetConstants::AssetFormat::IMAGE, status: MediaConstants::Status::PENDING)
    response = double("Response", body: "jpeg-bytes", headers: { content_type: "image/jpeg" })
    allow(RestClient::Request).to receive(:execute).and_return(response)
    allow(StorageService::Client).to receive(:upload).and_return(storage_key: "dev/user/avatar_google.jpg", url: "https://assets.example.test/avatar_google.jpg", bytes: 10, format: "jpg")

    described_class.perform_now(asset_id: asset.id, source_url: asset.url, storage_key: "user/avatar_google")

    expect(asset.reload).to have_attributes(storage_key: "dev/user/avatar_google.jpg", extension: "jpg", status: MediaConstants::Status::READY)
    expect(described_class.queue_name).to eq("media")
  end
end
