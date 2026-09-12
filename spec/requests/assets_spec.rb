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
      post "/v1/media/upload", params: { file: file, type: "avatar", assetable_type: "user", assetable_id: user.id }, headers: headers
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

  it "cleans up remote storage when the uploaded result cannot be saved" do
    existing = create(:asset, url: "https://cdn.example.com/taken.png")
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "profile/new", url: existing.url, bytes: 11, format: "png", resource_type: "image"
    )
    allow(StorageService::Client).to receive(:delete)

    expect do
      post "/v1/media/upload", params: { file: file }, headers: headers
    end.not_to change(Asset, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(StorageService::Client).to have_received(:delete).with("profile/new", resource_type: "image")
  end

  it "returns a server error without persisting when storage fails" do
    allow(StorageService::Client).to receive(:upload).and_raise(StorageService::Error, "storage offline")

    expect do
      post "/v1/media/upload", params: { file: file }, headers: headers
    end.not_to change(Asset, :count)
    expect(response).to have_http_status(:internal_server_error)
    expect(response_status["error"]).to eq("storage offline")
  end

  it "rejects files exceeding maximum size with localized error message" do
    allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(MediaConstants::MAX_NON_VIDEO_SIZE_MB.megabytes + 1)

    post "/v1/media/upload", params: { file: file }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["error"]).to eq("File size exceeds maximum allowed limit (#{MediaConstants::MAX_NON_VIDEO_SIZE_MB}MB)")
  end

  it "returns localized error message in Burmese when X-Locale is my" do
    allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(MediaConstants::MAX_NON_VIDEO_SIZE_MB.megabytes + 1)

    post "/v1/media/upload", params: { file: file }, headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["error"]).to eq("ဖိုင်အရွယ်အစားသည် သတ်မှတ်ထားသော ကန့်သတ်ချက်ထက် ကျော်လွန်နေပါသည် (#{MediaConstants::MAX_NON_VIDEO_SIZE_MB}MB)")
  end

  it "converts SVG to PNG on save as optimal without enqueueing image compression" do
    svg_file = fixture_file_upload("icon.svg", "image/svg+xml")
    tmpdir = Dir.mktmpdir("svg_to_png_spec")
    png_path = File.join(tmpdir, "icon.png")
    File.binwrite(png_path, "FAKEPNG")
    conversion = MediaService::SvgToPng::Result.new(file: png_path, filename: "icon.png", tmpdir: tmpdir)
    allow(MediaService::SvgToPng).to receive(:prepare).and_return(conversion)
    allow(Media::CompressImageJob).to receive(:perform_later)
    allow(StorageService::Client).to receive(:upload).and_return(
      storage_key: "user/#{user.id}/general_icon.png",
      url: "https://cdn.example.com/icon.png",
      bytes: 8,
      format: "png",
      resource_type: "image"
    )

    post "/v1/media/upload", params: { file: svg_file }, headers: headers

    expect(response).to have_http_status(:created)
    expect(Asset.last).to have_attributes(extension: "png", format: "image", status: "optimal")
    expect(StorageService::Client).to have_received(:upload).with(
      png_path,
      hash_including(storage_key: a_string_matching(/\.png$/), resource_type: "image")
    )
    expect(Media::CompressImageJob).not_to have_received(:perform_later)
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
      create(:asset, type: "video", format: "video", extension: "mp4")
      create(:asset, type: "avatar")

      get "/v1/assets", params: { type: "video" }

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "type")).to eq("video")
    end

    it "filters subtitle assets by type" do
      parent = create(:asset, type: "video", format: "video", extension: "mp4")
      create(:asset, type: "subtitle", format: "subtitle", extension: "srt", parent_asset: parent)
      create(:asset, type: "avatar")

      get "/v1/assets", params: { type: "subtitle" }

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "type")).to eq("subtitle")
    end
  end

  def grant_asset_create_permission(account)
    role = create(:role, name: "asset_uploader")
    permission = create(:permission, action: "create", resource: "assets")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: account, role: role)
  end
end
