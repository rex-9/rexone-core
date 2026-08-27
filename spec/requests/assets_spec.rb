require "rails_helper"

RSpec.describe "Asset uploads", type: :request do
  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_asset_create_permission(user)
  end

  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }
  let(:file) { fixture_file_upload("avatar.png", "image/png") }

  it "requires authentication" do
    post "/v1/media/upload", params: { file: file }
    expect(response).to have_http_status(:unauthorized)
  end

  it "requires a file" do
    post "/v1/media/upload", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["success"]).to be(false)
  end

  it "uploads and persists an image using the configured storage boundary" do
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "profile/avatar",
      url: "https://cdn.example.com/avatar.png",
      bytes: 11,
      format: "png",
      resource_type: "image"
    )

    expect do
      post "/v1/media/upload", params: { file: file, type: "avatar", resource_model: "user", resource_id: user.id }, headers: headers
    end.to change(Asset, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(Asset.last).to have_attributes(
      created_by_id: user.id,
      resource_model: "user",
      resource_id: user.id,
      type: "avatar",
      storage_key: "profile/avatar",
      format: "image",
      source: "upload"
    )
    expect(StorageService::Client).to have_received(:upload).with(
      kind_of(ActionDispatch::Http::UploadedFile),
      hash_including(folder: "avatar", resource_type: "image")
    )
  end

  it "maps documents and unknown extensions to their storage resource types" do
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "docs/report", url: "https://cdn.example.com/report.pdf", bytes: 4,
      format: "pdf", resource_type: "raw"
    )
    document = fixture_file_upload("report.pdf", "application/pdf")

    post "/v1/media/upload", params: { file: document }, headers: headers
    expect(response).to have_http_status(:created)
    expect(Asset.last.format).to eq("doc")
    expect(StorageService::Client).to have_received(:upload).with(anything, hash_including(resource_type: "raw"))
  end

  it "queues remote cleanup when the uploaded result cannot be saved" do
    existing = create(:asset, url: "https://cdn.example.com/taken.png")
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "profile/new", url: existing.url, bytes: 11, format: "png", resource_type: "image"
    )
    allow(StorageService::Client).to receive(:delete_later)

    expect do
      post "/v1/media/upload", params: { file: file }, headers: headers
    end.not_to change(Asset, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(StorageService::Client).to have_received(:delete_later).with("profile/new", resource_type: "image")
  end

  it "returns a server error without persisting when storage fails" do
    allow(StorageService::Client).to receive(:upload).and_raise(StorageService::Error, "storage offline")

    expect do
      post "/v1/media/upload", params: { file: file }, headers: headers
    end.not_to change(Asset, :count)
    expect(response).to have_http_status(:internal_server_error)
    expect(response_status["error"]).to eq("storage offline")
  end

  def grant_asset_create_permission(account)
    role = create(:role, name: "asset_uploader")
    permission = create(:permission, action: "create", resource: "assets")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: account, role: role)
  end
end
