require "rails_helper"

RSpec.describe "V1 Admin Assets API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "assets", :read, :create, :update, :delete)
  end

  describe "GET /v1/admin/assets" do
    it "returns paginated assets for admin" do
      create_list(:asset, 3)

      get "/v1/admin/assets", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

    it "filters assets by status, type, and format" do
      create(:asset, status: "pending", type: "thumbnail", format: "image")
      create(:asset, status: "ready", type: "video", format: "video")

      get "/v1/admin/assets", params: { status: "pending", type: "thumbnail", format: "image" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "status")).to eq("pending")
      expect(response_data.first.dig("attributes", "type")).to eq("thumbnail")
    end

    it "searches assets by name or storage_key" do
      needle = create(:asset, name: "Special Needle Asset", storage_key: "keys/special")
      create(:asset, name: "Other Asset", storage_key: "keys/other")

      get "/v1/admin/assets", params: { search: "Needle" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "id")).to eq(needle.id)
    end
  end

  describe "GET /v1/admin/assets/:id" do
    it "returns the requested asset details including status" do
      asset = create(:asset, status: "ready")

      get "/v1/admin/assets/#{asset.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "id")).to eq(asset.id)
      expect(response_data.dig("asset", "status")).to eq("ready")
      expect(response_data.dig("asset")).not_to have_key("created_by_id")
    end
  end

  describe "POST /v1/admin/assets/upload" do
    let(:image_file) { fixture_file_upload("avatar.png", "image/png") }

    before do
      allow(StorageService::Client).to receive(:upload).and_return(
        storage_key: "admin_uploads/avatar.png",
        url: "https://cdn.example.com/avatar.png",
        bytes: 1024,
        format: "png",
        resource_type: "image"
      )
    end

    it "uploads an asset to subfolder and sets status according to compression policy" do
      expect do
        post "/v1/admin/assets/upload", params: { file: image_file, type: "thumbnail" }, headers: headers
      end.to change(Asset, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response_data.dig("asset", "type")).to eq("thumbnail")
      expect(StorageService::Client).to have_received(:upload).with(
        anything,
        hash_including(folder: "admin_uploads/thumbnail")
      )
    end

    it "rejects files exceeding maximum size with localized error message" do
      allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(MediaConstants::MAX_NON_VIDEO_SIZE_MB.megabytes + 1)

      post "/v1/admin/assets/upload", params: { file: image_file, type: "thumbnail" }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to eq("File size exceeds maximum allowed limit (#{MediaConstants::MAX_NON_VIDEO_SIZE_MB}MB).")
    end

    it "returns localized error message in Burmese when X-Locale is my" do
      allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(MediaConstants::MAX_NON_VIDEO_SIZE_MB.megabytes + 1)

      post "/v1/admin/assets/upload",
           params: { file: image_file, type: "thumbnail" },
           headers: headers.merge("X-Locale" => "my")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["error"]).to eq("ဖိုင်အရွယ်အစားသည် သတ်မှတ်ထားသော ကန့်သတ်ချက်ထက် ကျော်လွန်နေပါသည် (#{MediaConstants::MAX_NON_VIDEO_SIZE_MB}MB)။")
    end
  end

  describe "POST /v1/admin/assets/:id/compress" do
    let(:image_asset) { create(:asset, extension: "png", status: "ready") }
    let(:video_asset) { create(:asset, extension: "mp4", status: "ready") }
    let(:pdf_asset) { create(:asset, extension: "pdf", status: "ready") }

    before do
      allow(Media::CompressImageJob).to receive(:perform_later)
      allow(Media::CompressVideoJob).to receive(:perform_later)
    end

    it "enqueues image compression for compressible image assets" do
      post "/v1/admin/assets/#{image_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "status")).to eq("pending")
      expect(image_asset.reload.status).to eq("pending")
      expect(Media::CompressImageJob).to have_received(:perform_later).with(asset_id: image_asset.id)
    end

    it "enqueues video compression for compressible video assets" do
      post "/v1/admin/assets/#{video_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "status")).to eq("pending")
      expect(video_asset.reload.status).to eq("pending")
      expect(Media::CompressVideoJob).to have_received(:perform_later).with(asset_id: video_asset.id)
    end

    it "rejects compression for non-compressible assets with 422" do
      post "/v1/admin/assets/#{pdf_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
      expect(Media::CompressVideoJob).not_to have_received(:perform_later)
    end

    it "rejects compression for already optimal assets with 422" do
      image_asset.update!(status: "optimal")

      post "/v1/admin/assets/#{image_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(response_status["message"]).to eq(I18n.t("admin.asset.compression_already_optimal"))
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
    end

    it "rejects compression for assets currently pending or processing with 422" do
      image_asset.update!(status: "pending")

      post "/v1/admin/assets/#{image_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(response_status["message"]).to eq(I18n.t("admin.asset.compression_in_progress"))
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
    end

    it "requires update_asset permission" do
      create_only_admin = create(:user)
      unauth_token = jwt_for(create_only_admin)
      allow(CacheService).to receive(:read).and_return(unauth_token)
      grant_admin_role(create_only_admin)

      role = Iam::Role.create!(name: "create_only_assets_admin_role")
      perm = Iam::Permission.find_or_create_by!(action: "create", resource: "assets")
      Iam::RolePermission.create!(role: role, permission: perm)
      Iam::UserRole.create!(user: create_only_admin, role: role)

      post "/v1/admin/assets/#{image_asset.id}/compress", headers: authorization_headers(unauth_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /v1/admin/assets/:id" do
    it "updates asset attributes" do
      asset = create(:asset, name: "Old Name")

      patch "/v1/admin/assets/#{asset.id}", params: { asset: { name: "Updated Name" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(asset.reload.name).to eq("Updated Name")
    end
  end

  describe "POST /v1/admin/assets/:id/discard and undiscard" do
    it "discards and undiscard an asset" do
      asset = create(:asset)

      post "/v1/admin/assets/#{asset.id}/discard", headers: headers
      expect(response).to have_http_status(:ok)
      expect(asset.reload.discarded?).to be(true)

      post "/v1/admin/assets/#{asset.id}/undiscard", headers: headers
      expect(response).to have_http_status(:ok)
      expect(asset.reload.discarded?).to be(false)
    end
  end

  describe "DELETE /v1/admin/assets/:id" do
    it "permanently destroys an asset" do
      asset = create(:asset)
      allow(StorageService::Client).to receive(:delete_later)

      delete "/v1/admin/assets/#{asset.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Asset.find_by(id: asset.id)).to be_nil
    end
  end
end
