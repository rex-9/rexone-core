# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1 Admin Assets Parent Assignment", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    allow(StorageService::Client).to receive(:move)
    allow(StorageService::Client).to receive(:url) { |key| "https://example.com/#{key}" }
    grant_admin_role(admin)
    grant_admin_permissions(admin, "assets", :read, :create, :update, :delete)
  end

  describe "PUT /v1/admin/assets/:id parent assignment" do
    let!(:video_parent) { create(:asset, type: "general", format: "video", name: "main_video.mp4", url: "https://example.com/main_video.mp4") }
    let!(:image_asset) { create(:asset, type: "general", format: "image", name: "cover.png", url: "https://example.com/cover.png") }
    let!(:subtitle_asset) { create(:asset, type: "general", format: "subtitle", name: "en.srt", url: "https://example.com/en.srt") }

    it "allows changing a main asset's type to thumbnail and assigning a parent asset" do
      patch "/v1/admin/assets/#{image_asset.id}",
            params: { asset: { type: "thumbnail", parent_asset_id: video_parent.id } },
            headers: headers

      expect(response).to have_http_status(:ok)
      image_asset.reload
      expect(image_asset.type).to eq("thumbnail")
      expect(image_asset.parent_asset_id).to eq(video_parent.id)
      expect(video_parent.reload.thumbnail.id).to eq(image_asset.id)
    end

    it "allows changing a main asset's type to subtitle and assigning a parent asset" do
      patch "/v1/admin/assets/#{subtitle_asset.id}",
            params: { asset: { type: "subtitle", parent_asset_id: video_parent.id } },
            headers: headers

      expect(response).to have_http_status(:ok)
      subtitle_asset.reload
      expect(subtitle_asset.type).to eq("subtitle")
      expect(subtitle_asset.parent_asset_id).to eq(video_parent.id)
      expect(video_parent.reload.subtitles.map(&:id)).to include(subtitle_asset.id)
    end

    it "prevents an asset from being assigned to itself as parent" do
      patch "/v1/admin/assets/#{image_asset.id}",
            params: { asset: { type: "thumbnail", parent_asset_id: image_asset.id } },
            headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response_status["error"]).to include("cannot be itself")
    end

    it "prevents an asset from being assigned to a child asset as parent" do
      thumb = create(:asset, type: "thumbnail", format: "image", parent_asset: video_parent, url: "https://example.com/thumb.png")

      patch "/v1/admin/assets/#{image_asset.id}",
            params: { asset: { type: "thumbnail", parent_asset_id: thumb.id } },
            headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response_status["error"]).to include("cannot be a child asset")
    end

    it "automatically replaces the existing thumbnail when parent already has a thumbnail" do
      existing_thumb = create(:asset, type: "thumbnail", format: "image", parent_asset: video_parent, url: "https://example.com/old_thumb.png")

      patch "/v1/admin/assets/#{image_asset.id}",
            params: { asset: { type: "thumbnail", parent_asset_id: video_parent.id } },
            headers: headers

      expect(response).to have_http_status(:ok)
      image_asset.reload
      expect(image_asset.type).to eq("thumbnail")
      expect(image_asset.parent_asset_id).to eq(video_parent.id)
      expect(video_parent.reload.thumbnail.id).to eq(image_asset.id)
      expect(Asset.find_by(id: existing_thumb.id)).to be_nil
    end
  end

  describe "POST /v1/admin/assets/upload parent assignment" do
    let!(:video_parent) { create(:asset, type: "general", format: "video", name: "main_video.mp4", url: "https://example.com/main_video.mp4") }
    let(:file) { fixture_file_upload("avatar.png", "image/png") }

    before do
      allow(StorageService::Client).to receive(:upload).and_return({
        storage_key: "avatar/test_upload_thumb.png",
        url: "https://example.com/avatar/test_upload_thumb.png",
        bytes: 1024,
        format: "png"
      })
    end

    it "automatically replaces an existing thumbnail when uploading a new thumbnail for a parent asset" do
      existing_thumb = create(:asset, type: "thumbnail", format: "image", parent_asset: video_parent, url: "https://example.com/old_thumb.png")

      post "/v1/admin/assets/upload",
           params: { file: file, type: "thumbnail", parent_asset_id: video_parent.id },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(video_parent.reload.thumbnail.id).not_to eq(existing_thumb.id)
      expect(Asset.find_by(id: existing_thumb.id)).to be_nil
    end
  end
end
