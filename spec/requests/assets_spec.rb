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
    post "/v1/assets/upload", params: { file: file }
    expect(response).to have_http_status(:unauthorized)
  end

  it "requires a file" do
    post "/v1/assets/upload", headers: headers
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
      post "/v1/assets/upload", params: { file: file, type: "avatar", assetable_type: "user", assetable_id: user.id }, headers: headers
    end.to change(Asset, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(Asset.last).to have_attributes(
      created_by_id: user.id,
      assetable_type: "user",
      assetable_id: user.id,
      type: "avatar",
      storage_key: "profile/avatar",
      format: "image",
      source: "upload"
    )
    expect(StorageService::Client).to have_received(:upload).with(
      kind_of(ActionDispatch::Http::UploadedFile),
      hash_including(resource_type: "image", storage_key: a_string_matching(/\Auser\/#{user.id}\/avatar_/))
    )
  end

  it "persists display_name and description on upload, defaulting display_name to original_filename" do
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "profile/avatar_custom",
      url: "https://cdn.example.com/avatar_custom.png",
      bytes: 11,
      format: "png",
      resource_type: "image"
    )

    post "/v1/assets/upload", params: { file: file, display_name: "My Avatar", description: "Profile photo description" }, headers: headers

    expect(response).to have_http_status(:created)
    expect(Asset.last).to have_attributes(
      display_name: "My Avatar",
      description: "Profile photo description"
    )
    expect(response_data.dig("asset", "display_name")).to eq("My Avatar")
    expect(response_data.dig("asset", "description")).to eq("Profile photo description")
  end

  it "maps documents and unknown extensions to their storage resource types" do
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "docs/report", url: "https://cdn.example.com/report.pdf", bytes: 4,
      format: "pdf", resource_type: "raw"
    )
    document = fixture_file_upload("report.pdf", "application/pdf")

    post "/v1/assets/upload", params: { file: document }, headers: headers
    expect(response).to have_http_status(:created)
    expect(Asset.last.format).to eq("doc")
    expect(StorageService::Client).to have_received(:upload).with(anything, hash_including(resource_type: "raw"))
  end

  it "cleans up remote storage when the uploaded result cannot be saved" do
    existing = create(:asset, url: "https://cdn.example.com/taken.png")
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "profile/new", url: existing.url, bytes: 11, format: "png", resource_type: "image"
    )
    allow(StorageService::Client).to receive(:delete)

    expect do
      post "/v1/assets/upload", params: { file: file }, headers: headers
    end.not_to change(Asset, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(StorageService::Client).to have_received(:delete).with("profile/new", resource_type: "image")
  end

  it "returns a server error without persisting when storage fails" do
    allow(StorageService::Client).to receive(:upload).and_raise(StorageService::Error, "storage offline")

    expect do
      post "/v1/assets/upload", params: { file: file }, headers: headers
    end.not_to change(Asset, :count)
    expect(response).to have_http_status(:internal_server_error)
    expect(response_status["error"]).to eq("Storage upload failed")
  end

  it "rejects files exceeding maximum size with localized error message" do
    allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(MediaConstants::MAX_IMAGE_SIZE_MB.megabytes + 1)

    post "/v1/assets/upload", params: { file: file }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["error"]).to eq("File size exceeds maximum allowed limit (#{MediaConstants::MAX_IMAGE_SIZE_MB}MB)")
  end

  it "returns localized error message in Burmese when X-Locale is my" do
    allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(MediaConstants::MAX_IMAGE_SIZE_MB.megabytes + 1)

    post "/v1/assets/upload", params: { file: file }, headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["error"]).to eq("ဖိုင်အရွယ်အစားသည် သတ်မှတ်ထားသော ကန့်သတ်ချက်ထက် ကျော်လွန်နေပါသည် (#{MediaConstants::MAX_IMAGE_SIZE_MB}MB)")
  end

  it "stores SVG unchanged and queues conversion in the media worker" do
    svg_file = fixture_file_upload("icon.svg", "image/svg+xml")
    allow(Media::ConvertImageJob).to receive(:perform_later)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "user/#{user.id}/general_icon.svg",
      url: "https://cdn.example.com/icon.svg",
      bytes: 8,
      format: "svg",
      resource_type: "image"
    )

    post "/v1/assets/upload", params: { file: svg_file }, headers: headers

    expect(response).to have_http_status(:created)
    expect(Asset.last).to have_attributes(extension: "svg", format: "image", status: "pending")
    expect(StorageService::Client).to have_received(:upload).with(
      anything,
      hash_including(storage_key: a_string_matching(/\.svg$/), resource_type: "image")
    )
    expect(Media::ConvertImageJob).to have_received(:perform_later).with(asset_id: Asset.last.id)
  end

  describe "GET /v1/assets" do
    it "returns paginated assets" do
      create_list(:asset, 3)

      get "/v1/assets", params: { limit: 2 }

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

    it "filters assets by type" do
      create(:asset, type: "attachment", format: "video", extension: "mp4")
      create(:asset, type: "avatar")

      get "/v1/assets", params: { type: "attachment" }

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "type")).to eq("attachment")
    end

    it "filters subtitle assets by type" do
      parent = create(:asset, type: "general", format: "video", extension: "mp4")
      create(:asset, type: "subtitle", format: "subtitle", extension: "srt", parent_asset: parent)
      create(:asset, type: "avatar")

      get "/v1/assets", params: { type: "subtitle", record_scope: "children" }

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "type")).to eq("subtitle")
    end
  end

  describe "GET /v1/assets/:id/playback" do
    before do
      grant_permissions(user, "assets", :read)
    end

    it "returns progressive playback delivery for ready video" do
      asset = create(:asset, type: "general", format: "video", extension: "mp4", status: "ready", storage_key: "user/#{user.id}/video.mp4")
      thumbnail = create(:asset, type: "thumbnail", format: "image", extension: "webp", parent_asset: asset, storage_key: "user/#{user.id}/thumbnail.webp")
      subtitle = create(:asset, type: "subtitle", format: "subtitle", extension: "srt", parent_asset: asset, storage_key: "user/#{user.id}/subtitle.srt")
      expires_at = 1.hour.from_now
      allow(StorageService::Client).to receive(:playback_url).and_return(
        type: "progressive",
        url: "https://media.example.com/video.mp4?signature=secret",
        expires_at: expires_at
      )

      get "/v1/assets/#{asset.id}/playback", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to include(
        "asset_id" => asset.id,
        "delivery" => {
          "type" => "progressive",
          "url" => "https://media.example.com/video.mp4?signature=secret",
          "expires_at" => expires_at.iso8601
        }
      )
      expect(response_data.dig("media", "content_type")).to eq("video/mp4")
      expect(response_data.dig("media", "thumbnail", "id")).to eq(thumbnail.id)
      expect(response_data.dig("media", "subtitles").first["id"]).to eq(subtitle.id)
      expect(StorageService::Client).to have_received(:playback_url).with(
        asset,
        expires_in: MediaConstants::PLAYBACK_URL_TTL
      )
    end

    it "returns progressive playback delivery for optimal audio" do
      asset = create(:asset, type: "general", format: "audio", extension: "mp3", status: "optimal", storage_key: "user/#{user.id}/audio.mp3")
      allow(StorageService::Client).to receive(:playback_url).and_return(
        type: "progressive",
        url: "https://media.example.com/audio.mp3?signature=secret",
        expires_at: 1.hour.from_now
      )

      get "/v1/assets/#{asset.id}/playback", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("media", "content_type")).to eq("audio/mpeg")
    end

    it "requires authentication" do
      asset = create(:asset, type: "general", format: "video", extension: "mp4", status: "ready")

      get "/v1/assets/#{asset.id}/playback"

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires read asset permission" do
      unauthorized_user = create(:user)
      unauthorized_token = jwt_for(unauthorized_user)
      allow(CacheService).to receive(:read).and_return(unauthorized_token)
      asset = create(:asset, type: "general", format: "video", extension: "mp4", status: "ready")

      get "/v1/assets/#{asset.id}/playback", headers: authorization_headers(unauthorized_token)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects pending assets" do
      asset = create(:asset, type: "general", format: "video", extension: "mp4", status: "pending")

      get "/v1/assets/#{asset.id}/playback", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(response_status["error"]).to eq("Asset is not ready for playback")
    end

    it "rejects unsupported assets" do
      asset = create(:asset, type: "general", format: "image", extension: "png", status: "ready")

      get "/v1/assets/#{asset.id}/playback", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to eq("Asset format is not supported for playback")
    end

    it "rejects assets without storage keys" do
      asset = create(:asset, type: "general", format: "video", extension: "mp4", status: "ready", storage_key: nil, source: "google")

      get "/v1/assets/#{asset.id}/playback", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to eq("Asset storage file is missing")
    end

    it "does not expose storage provider errors" do
      asset = create(:asset, type: "general", format: "video", extension: "mp4", status: "ready")
      allow(StorageService::Client).to receive(:playback_url).and_raise(StorageService::Error, "secret provider failure")

      get "/v1/assets/#{asset.id}/playback", headers: headers

      expect(response).to have_http_status(:service_unavailable)
      expect(response_status["error"]).to eq("Failed to prepare playback URL")
      expect(response.body).not_to include("secret provider failure")
    end
  end

  describe "PUT /v1/assets/:id" do
    it "updates display_name and description" do
      grant_asset_update_permission(user)
      asset = create(:asset, creator: user, name: "old_name.png", display_name: "old_name.png")

      put "/v1/assets/#{asset.id}", params: { asset: { display_name: "Custom Display Name", description: "Updated description text" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(asset.reload.display_name).to eq("Custom Display Name")
      expect(asset.description).to eq("Updated description text")
      expect(response_data.dig("asset", "display_name")).to eq("Custom Display Name")
      expect(response_data.dig("asset", "description")).to eq("Updated description text")
    end
  end

  def grant_asset_create_permission(account)
    role = create(:role, name: "asset_uploader")
    permission = create(:permission, action: "create", resource: "assets")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: account, role: role)
  end

  def grant_asset_update_permission(account)
    role = create(:role, name: "asset_updater")
    permission = create(:permission, action: "update", resource: "assets")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: account, role: role)
  end
end
