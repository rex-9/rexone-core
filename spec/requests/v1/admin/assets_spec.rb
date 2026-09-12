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

    it "lists assets from every storage partition" do
      stub_const("AppConfig::S3_FOLDER_PREFIX", "dev")
      dev_asset = create(:asset, storage_key: "dev/images/current.png")
      uat_asset = create(:asset, storage_key: "uat/images/foreign.png")
      prod_asset = create(:asset, storage_key: "prod/images/foreign.png")

      get "/v1/admin/assets", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.map { |asset| asset.dig("attributes", "id") }).to contain_exactly(
        dev_asset.id,
        uat_asset.id,
        prod_asset.id
      )
    end

    it "safely handles serialization when AppConfig::S3_FOLDER_PREFIX is undefined" do
      hide_const("AppConfig::S3_FOLDER_PREFIX")
      create(:asset, name: "Resilient Asset", storage_key: "dev/images/resilient.png")

      get "/v1/admin/assets", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.first.dig("attributes", "name")).to eq("Resilient Asset")
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

    it "allows direct access to an asset from another environment partition" do
      stub_const("AppConfig::S3_FOLDER_PREFIX", "dev")
      prod_asset = create(:asset, storage_key: "prod/images/shared.png")

      get "/v1/admin/assets/#{prod_asset.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "id")).to eq(prod_asset.id)
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
        hash_including(storage_key: a_string_matching(/^admin\/thumbnail_avatar_\d+\.png$/))
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

    it "converts SVG to PNG on save as optimal without enqueueing image compression" do
      svg_file = fixture_file_upload("icon.svg", "image/svg+xml")
      conversion = stub_svg_to_png_result
      allow(MediaService::SvgToPng).to receive(:prepare).and_return(conversion)
      allow(Media::CompressImageJob).to receive(:perform_later)
      allow(StorageService::Client).to receive(:upload).and_return(
        storage_key: "admin/general_icon.png",
        url: "https://cdn.example.com/icon.png",
        bytes: 8,
        format: "png",
        resource_type: "image"
      )

      post "/v1/admin/assets/upload", params: { file: svg_file, type: "general" }, headers: headers

      expect(response).to have_http_status(:created)
      expect(Asset.last).to have_attributes(extension: "png", format: "image", status: "optimal")
      expect(StorageService::Client).to have_received(:upload).with(
        conversion.file,
        hash_including(storage_key: a_string_matching(/\.png$/), resource_type: "image")
      )
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
    end
  end

  describe "POST /v1/admin/assets/:id/compress" do
    let(:image_asset) { create(:asset, extension: "png", status: "ready") }
    let(:video_asset) { create(:asset, extension: "mp4", status: "ready") }
    let(:audio_asset) { create(:asset, extension: "wav", format: "audio", type: "audio", status: "ready") }
    let(:pdf_asset) { create(:asset, extension: "pdf", status: "ready") }

    before do
      allow(Media::CompressImageJob).to receive(:perform_later)
      allow(Media::CompressVideoJob).to receive(:perform_later)
      allow(Media::CompressAudioJob).to receive(:perform_later)
    end

    it "enqueues image compression for compressible image assets" do
      post "/v1/admin/assets/#{image_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "status")).to eq("pending")
      expect(image_asset.reload.status).to eq("pending")
      expect(Media::CompressImageJob).to have_received(:perform_later).with(
        hash_including(
          asset_id: image_asset.id,
          notification_user_id: admin.id,
          operation_id: start_with("asset_compression:#{image_asset.id}:")
        )
      )
      expect(response_data["operation_id"]).to start_with("asset_compression:#{image_asset.id}:")
    end

    it "enqueues image compression for webp assets" do
      webp_asset = create(:asset, extension: "webp", format: "image", status: "ready")

      post "/v1/admin/assets/#{webp_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:ok)
      expect(webp_asset.reload.status).to eq("pending")
      expect(Media::CompressImageJob).to have_received(:perform_later).with(
        hash_including(
          asset_id: webp_asset.id,
          notification_user_id: admin.id,
          operation_id: start_with("asset_compression:#{webp_asset.id}:")
        )
      )
    end

    it "enqueues video compression for compressible video assets" do
      post "/v1/admin/assets/#{video_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "status")).to eq("pending")
      expect(video_asset.reload.status).to eq("pending")
      expect(Media::CompressVideoJob).to have_received(:perform_later).with(
        hash_including(
          asset_id: video_asset.id,
          notification_user_id: admin.id,
          operation_id: start_with("asset_compression:#{video_asset.id}:")
        )
      )
      expect(response_data["operation_id"]).to start_with("asset_compression:#{video_asset.id}:")
    end

    it "enqueues audio compression for compressible audio assets" do
      post "/v1/admin/assets/#{audio_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("asset", "status")).to eq("pending")
      expect(audio_asset.reload.status).to eq("pending")
      expect(Media::CompressAudioJob).to have_received(:perform_later).with(
        hash_including(
          asset_id: audio_asset.id,
          notification_user_id: admin.id,
          operation_id: start_with("asset_compression:#{audio_asset.id}:")
        )
      )
      expect(response_data["operation_id"]).to start_with("asset_compression:#{audio_asset.id}:")
    end

    it "rejects compression for non-compressible assets with 422" do
      post "/v1/admin/assets/#{pdf_asset.id}/compress", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
      expect(Media::CompressVideoJob).not_to have_received(:perform_later)
      expect(Media::CompressAudioJob).not_to have_received(:perform_later)
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

  describe "GET /v1/admin/assets/:id/download" do
    it "returns an attachment URL for the asset" do
      asset = create(:asset, name: "demo video.mp4")
      allow_any_instance_of(Asset).to receive(:storage_url).and_return("https://assets.example.com/download")

      get "/v1/admin/assets/#{asset.id}/download", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(response_data["download_url"]).to eq("https://assets.example.com/download")
    end
  end

  describe "POST /v1/admin/assets/:id/thumbnail/regenerate" do
    let(:video_asset) { create(:asset, format: "video", extension: "mp4") }

    before { allow(Media::GenerateVideoThumbnailJob).to receive(:perform_later) }

    it "accepts and queues replacement thumbnail generation" do
      post "/v1/admin/assets/#{video_asset.id}/thumbnail/regenerate", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(response_status["success"]).to be(true)
      expect(Media::GenerateVideoThumbnailJob).to have_received(:perform_later).with(
        hash_including(
          asset_id: video_asset.id,
          replace: true,
          notification_user_id: admin.id,
          operation_id: start_with("video_thumbnail:#{video_asset.id}:")
        )
      )
      expect(response_data["operation_id"]).to start_with("video_thumbnail:#{video_asset.id}:")
    end

    it "rejects non-video assets" do
      image = create(:asset, format: "image", extension: "png")

      post "/v1/admin/assets/#{image.id}/thumbnail/regenerate", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
    end
  end

  describe "POST /v1/admin/assets/:id/thumbnail/upload" do
    let(:video_asset) { create(:asset, format: "video", extension: "mp4") }
    let(:image_file) { fixture_file_upload("avatar.png", "image/png") }

    before do
      allow(StorageService::Client).to receive(:upload).and_return(
        storage_key: "dev/admin/thumbnail_replacement.webp",
        url: "https://assets.example.com/thumbnail-replacement.webp",
        bytes: 512,
        format: "webp"
      )
      allow(StorageService::Client).to receive(:delete).and_return(true)
    end

    it "replaces the existing thumbnail record and storage object" do
      previous = create(
        :asset,
        type: "thumbnail",
        format: "image",
        extension: "webp",
        parent_asset: video_asset,
        storage_key: "dev/admin/thumbnail_previous.webp"
      )

      post "/v1/admin/assets/#{video_asset.id}/thumbnail/upload",
           params: { file: image_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(Asset.exists?(previous.id)).to be(false)
      expect(video_asset.reload.thumbnail.storage_key).to eq("dev/admin/thumbnail_replacement.webp")
      expect(response_data.dig("asset", "thumbnail", "url")).to include("dev/admin/thumbnail_replacement.webp")
      expect(StorageService::Client).to have_received(:delete).with(
        "dev/admin/thumbnail_previous.webp",
        resource_type: "image"
      )
    end

    it "rejects a non-image replacement" do
      document = fixture_file_upload("report.pdf", "application/pdf")

      post "/v1/admin/assets/#{video_asset.id}/thumbnail/upload",
           params: { file: document },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(StorageService::Client).not_to have_received(:upload)
    end

    it "attaches a thumbnail to a type=audio parent" do
      audio_asset = create(:asset, type: "audio", format: "audio", extension: "wav")

      post "/v1/admin/assets/#{audio_asset.id}/thumbnail/upload",
           params: { file: image_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(audio_asset.reload.thumbnail.storage_key).to eq("dev/admin/thumbnail_replacement.webp")
      expect(response_data.dig("asset", "thumbnail", "url")).to include("dev/admin/thumbnail_replacement.webp")
    end

    it "attaches a thumbnail to a compressible audio parent regardless of type" do
      general_wav = create(:asset, type: "general", format: "audio", extension: "wav")

      post "/v1/admin/assets/#{general_wav.id}/thumbnail/upload",
           params: { file: image_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(general_wav.reload.thumbnail.storage_key).to eq("dev/admin/thumbnail_replacement.webp")
      expect(StorageService::Client).to have_received(:upload)
    end

    it "rejects a non-audio, non-video parent" do
      pdf_asset = create(:asset, type: "general", format: "doc", extension: "pdf")

      post "/v1/admin/assets/#{pdf_asset.id}/thumbnail/upload",
           params: { file: image_file },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(StorageService::Client).not_to have_received(:upload)
    end

    it "converts an SVG cover to PNG before storing the thumbnail" do
      svg_file = fixture_file_upload("icon.svg", "image/svg+xml")
      conversion = stub_svg_to_png_result
      allow(MediaService::SvgToPng).to receive(:prepare).and_return(conversion)
      allow(Media::CompressImageJob).to receive(:perform_later)
      allow(StorageService::Client).to receive(:upload).and_return(
        storage_key: "dev/admin/thumbnail_replacement.png",
        url: "https://assets.example.com/thumbnail-replacement.png",
        bytes: 512,
        format: "png"
      )

      post "/v1/admin/assets/#{video_asset.id}/thumbnail/upload",
           params: { file: svg_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(video_asset.reload.thumbnail).to have_attributes(extension: "png", status: "optimal")
      expect(StorageService::Client).to have_received(:upload).with(
        conversion.file,
        hash_including(resource_type: "image", storage_key: a_string_matching(/\.png$/))
      )
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
    end
  end

  describe "POST /v1/admin/assets/:id/subtitle/upload" do
    let(:video_asset) { create(:asset, format: "video", extension: "mp4") }
    let(:srt_file) { fixture_file_upload("captions.srt", "application/x-subrip") }

    before do
      allow(StorageService::Client).to receive(:upload).and_return(
        storage_key: "dev/admin/subtitle_replacement.srt",
        url: "https://assets.example.com/subtitle-replacement.srt",
        bytes: 128,
        format: "srt"
      )
      allow(StorageService::Client).to receive(:delete).and_return(true)
      allow(StorageService::Client).to receive(:url) { |key, *_| "https://assets.example.com/#{key}" }
      allow(Media::CompressImageJob).to receive(:perform_later)
      allow(Media::CompressVideoJob).to receive(:perform_later)
      allow(Media::CompressAudioJob).to receive(:perform_later)
    end

    it "attaches an srt subtitle to a video parent without enqueueing compression" do
      post "/v1/admin/assets/#{video_asset.id}/subtitle/upload",
           params: { file: srt_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(video_asset.reload.subtitle).to have_attributes(
        type: "subtitle",
        format: "subtitle",
        extension: "srt",
        status: "ready",
        storage_key: "dev/admin/subtitle_replacement.srt"
      )
      expect(response_data.dig("asset", "subtitle", "url")).to include("dev/admin/subtitle_replacement.srt")
      expect(response_data.dig("asset", "subtitle", "status")).to eq("ready")
      expect(StorageService::Client).to have_received(:upload).with(
        anything,
        hash_including(resource_type: "raw")
      )
      expect(Media::CompressImageJob).not_to have_received(:perform_later)
      expect(Media::CompressVideoJob).not_to have_received(:perform_later)
      expect(Media::CompressAudioJob).not_to have_received(:perform_later)
    end

    it "replaces the existing subtitle record and storage object" do
      previous = create(
        :asset,
        type: "subtitle",
        format: "subtitle",
        extension: "srt",
        parent_asset: video_asset,
        storage_key: "dev/admin/subtitle_previous.srt"
      )

      post "/v1/admin/assets/#{video_asset.id}/subtitle/upload",
           params: { file: srt_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(Asset.exists?(previous.id)).to be(false)
      expect(video_asset.reload.subtitle.storage_key).to eq("dev/admin/subtitle_replacement.srt")
      expect(response_data.dig("asset", "subtitle", "url")).to include("dev/admin/subtitle_replacement.srt")
      expect(StorageService::Client).to have_received(:delete).with(
        "dev/admin/subtitle_previous.srt",
        resource_type: "raw"
      )
    end

    it "rejects a non-srt replacement" do
      image = fixture_file_upload("avatar.png", "image/png")

      post "/v1/admin/assets/#{video_asset.id}/subtitle/upload",
           params: { file: image },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(StorageService::Client).not_to have_received(:upload)
    end

    it "attaches a subtitle to a type=audio parent" do
      audio_asset = create(:asset, type: "audio", format: "audio", extension: "wav")

      post "/v1/admin/assets/#{audio_asset.id}/subtitle/upload",
           params: { file: srt_file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["success"]).to be(true)
      expect(audio_asset.reload.subtitle.storage_key).to eq("dev/admin/subtitle_replacement.srt")
      expect(response_data.dig("asset", "subtitle", "url")).to include("dev/admin/subtitle_replacement.srt")
    end

    it "rejects a non-audio, non-video parent" do
      image_asset = create(:asset, format: "image", extension: "png")
      pdf_asset = create(:asset, type: "general", format: "doc", extension: "pdf")

      post "/v1/admin/assets/#{image_asset.id}/subtitle/upload",
           params: { file: srt_file },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["success"]).to be(false)
      expect(StorageService::Client).not_to have_received(:upload)

      post "/v1/admin/assets/#{pdf_asset.id}/subtitle/upload",
           params: { file: srt_file },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(StorageService::Client).not_to have_received(:upload)
    end
  end

  describe "GET /v1/admin/assets/storage_stats" do
    it "returns storage statistics" do
      grant_super_admin_role(admin)
      allow(StorageService::Client).to receive(:storage_stats).and_return(
        provider: "garage",
        bucket: "rexone",
        bucket_bytes: 5000,
        bucket_objects: 5,
        partitions: {
          dev: { bytes: 1000, objects: 1 },
          uat: { bytes: 1500, objects: 2 },
          prod: { bytes: 2500, objects: 2 }
        },
        tracked_partitions: {
          dev: { bytes: 1000, objects: 1 },
          uat: { bytes: 0, objects: 0 },
          prod: { bytes: 1000, objects: 1 }
        },
        disk_available_bytes: 50_000_000_000,
        disk_total_bytes: 60_000_000_000,
        disk_used_percent: 16.7,
        disk_free_percent: 83.3,
        node_capacity_bytes: 1_000_000_000
      )
      create_list(:asset, 2, size_bytes: 1000)

      get "/v1/admin/assets/storage_stats", headers: headers

      expect(response).to have_http_status(:ok)
      stats = response_data.dig("stats")
      expect(stats["provider"]).to eq("garage")
      expect(stats["bucket"]).to eq("rexone")
      expect(stats["bucket_bytes"]).to eq(5000)
      expect(stats["bucket_objects"]).to eq(5)
      expect(stats.dig("partitions", "dev", "bytes")).to eq(1000)
      expect(stats.dig("partitions", "prod", "objects")).to eq(2)
      expect(stats.dig("tracked_partitions", "dev", "objects")).to eq(1)
      expect(stats["db_assets_count"]).to eq(2)
      expect(stats["db_assets_bytes"]).to eq(2000)
    end

    it "counts database assets across all environment partitions" do
      grant_super_admin_role(admin)
      stub_const("AppConfig::S3_FOLDER_PREFIX", "dev")
      allow(StorageService::Client).to receive(:storage_stats).and_return(
        provider: "garage",
        bucket: "rexone",
        bucket_bytes: 5000,
        bucket_objects: 5,
        disk_available_bytes: 50_000_000_000,
        disk_total_bytes: 60_000_000_000,
        disk_used_percent: 16.7,
        disk_free_percent: 83.3,
        node_capacity_bytes: 1_000_000_000
      )
      create(:asset, storage_key: "dev/images/1.png", size_bytes: 1000)
      create(:asset, storage_key: "prod/images/2.png", size_bytes: 5000)

      get "/v1/admin/assets/storage_stats", headers: headers

      expect(response).to have_http_status(:ok)
      stats = response_data.dig("stats")
      expect(stats["db_assets_count"]).to eq(2)
      expect(stats["db_assets_bytes"]).to eq(6000)
    end

    it "requires super admin access" do
      get "/v1/admin/assets/storage_stats", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to eq(I18n.t("common.authorization.super_admin_required"))
    end
  end

  describe "PATCH /v1/admin/assets/:id" do
    it "updates asset attributes" do
      asset = create(:asset, name: "Old Name")

      patch "/v1/admin/assets/#{asset.id}", params: { asset: { name: "Updated Name" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(asset.reload.name).to eq("Updated Name")
    end

    it "renames storage key and name when asset type changes" do
      asset = create(:asset,
        name: "admin/avatar_company_1788500000.png",
        storage_key: "admin/avatar_company_1788500000.png",
        type: "avatar",
        source: AssetConstants::AssetSource::UPLOAD
      )
      allow(StorageService::Client).to receive(:move)
      allow(StorageService::Client).to receive(:url).and_return("http://localhost:3100/rexone/admin/thumbnail_company_1788500000.png")

      patch "/v1/admin/assets/#{asset.id}", params: { asset: { type: "thumbnail" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(StorageService::Client).to have_received(:move).with(
        "admin/avatar_company_1788500000.png",
        "admin/thumbnail_company_1788500000.png"
      )
      expect(asset.reload.type).to eq("thumbnail")
      expect(asset.storage_key).to eq("admin/thumbnail_company_1788500000.png")
      expect(asset.name).to eq("admin/thumbnail_company_1788500000.png")
    end

    it "renames name and storage key even when form submits stale old name" do
      asset = create(:asset,
        name: "admin/general_sayadaw-kelasa_1788540008.png",
        storage_key: "admin/general_sayadaw-kelasa_1788540008.png",
        type: "general",
        source: AssetConstants::AssetSource::UPLOAD
      )
      allow(StorageService::Client).to receive(:move)
      allow(StorageService::Client).to receive(:url).and_return("http://localhost:3100/rexone/admin/video_sayadaw-kelasa_1788540008.png")

      patch "/v1/admin/assets/#{asset.id}",
            params: {
              asset: {
                name: "admin/general_sayadaw-kelasa_1788540008.png",
                type: "video"
              }
            },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(StorageService::Client).to have_received(:move).with(
        "admin/general_sayadaw-kelasa_1788540008.png",
        "admin/video_sayadaw-kelasa_1788540008.png"
      )
      expect(asset.reload.type).to eq("video")
      expect(asset.storage_key).to eq("admin/video_sayadaw-kelasa_1788540008.png")
      expect(asset.name).to eq("admin/video_sayadaw-kelasa_1788540008.png")
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
      allow(StorageService::Client).to receive(:delete)

      delete "/v1/admin/assets/#{asset.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Asset.find_by(id: asset.id)).to be_nil
    end
  end

  describe "DELETE /v1/admin/assets/bin and /empty_recycle_bin" do
    it "permanently purges all discarded assets via /bin" do
      kept_asset = create(:asset)
      discarded_assets = create_list(:asset, 3)
      discarded_assets.each(&:discard!)

      allow(StorageService::Client).to receive(:delete)

      delete "/v1/admin/assets/bin", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(3)
      expect(Asset.kept.count).to eq(1)
      expect(Asset.with_discarded.discarded.count).to eq(0)
      expect(Asset.find_by(id: kept_asset.id)).to be_present
    end

    it "permanently purges all discarded assets via /bin" do
      discarded_assets = create_list(:asset, 2)
      discarded_assets.each(&:discard!)

      delete "/v1/admin/assets/bin", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(Asset.with_discarded.discarded.count).to eq(0)
    end
  end

  describe "POST /v1/admin/assets/discard_batch" do
    it "discards multiple selected assets" do
      assets = create_list(:asset, 3)
      ids_to_discard = assets.first(2).map(&:id)

      post "/v1/admin/assets/discard_batch", params: { ids: ids_to_discard }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(Asset.kept.count).to eq(1)
      expect(Asset.with_discarded.discarded.count).to eq(2)
    end

    it "rejects empty ids with 422" do
      post "/v1/admin/assets/discard_batch", params: { ids: [] }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /v1/admin/assets/undiscard_batch" do
    it "restores multiple selected discarded assets" do
      assets = create_list(:asset, 3)
      assets.each(&:discard!)

      ids_to_restore = assets.first(2).map(&:id)

      post "/v1/admin/assets/undiscard_batch", params: { ids: ids_to_restore }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(Asset.kept.count).to eq(2)
      expect(Asset.with_discarded.discarded.count).to eq(1)
    end
  end

  describe "POST /v1/admin/assets/destroy_batch" do
    it "permanently deletes multiple selected assets and queues storage deletions" do
      assets = create_list(:asset, 3)
      ids_to_destroy = assets.first(2).map(&:id)

      allow(StorageService::Client).to receive(:delete)

      post "/v1/admin/assets/destroy_batch", params: { ids: ids_to_destroy }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["count"]).to eq(2)
      expect(Asset.with_discarded.count).to eq(1)
      expect(Asset.find_by(id: assets.last.id)).to be_present
    end
  end

  def stub_svg_to_png_result
    tmpdir = Dir.mktmpdir("svg_to_png_spec")
    png_path = File.join(tmpdir, "icon.png")
    File.binwrite(png_path, "FAKEPNG")
    MediaService::SvgToPng::Result.new(file: png_path, filename: "icon.png", tmpdir: tmpdir)
  end
end
