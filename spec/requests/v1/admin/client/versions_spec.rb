require "rails_helper"

RSpec.describe "V1 Admin Versions API", type: :request do
  let(:admin) { create(:user) }
  let(:super_admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:super_token) { jwt_for(super_admin) }
  let(:headers) { authorization_headers(super_token) }
  let(:admin_headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:write)
    allow(CacheService).to receive(:read).and_return(super_token)
    allow(CacheService).to receive(:read).with("active_session:user:#{admin.id}:web").and_return(token)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "versions", :read, :create, :update, :delete)
    grant_super_admin_role(super_admin)
  end

  describe "GET /v1/admin/client/versions" do
    it "lists versions for super admins" do
      create(:version, :published, number: "1.2.0", title: "Live")
      create(:version, number: "1.3.0", title: "Draft")

      get "/v1/admin/client/versions", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("version.fetched"))
      expect(response_data.size).to eq(2)
    end

    it "filters versions by status" do
      create(:version, :published, number: "1.2.0")
      create(:version, number: "1.3.0")

      get "/v1/admin/client/versions", params: { status: "published" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "number")).to eq("1.2.0")
    end

    it "forbids a regular admin even with versions permissions" do
      get "/v1/admin/client/versions", headers: admin_headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to eq(I18n.t("common.authorization.super_admin_required"))
    end

    it "rejects non-admin users even with read_versions" do
      user = create(:user)
      user_token = jwt_for(user)
      grant_permissions(user, "versions", :read)
      allow(CacheService).to receive(:read).with("active_session:user:#{user.id}:web").and_return(user_token)

      get "/v1/admin/client/versions", headers: authorization_headers(user_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /v1/admin/client/versions/:id" do
    it "returns version fields including force-update and build numbers" do
      version = create(
        :version, :published, :force,
        number: "1.4.0",
        title: "Force",
        ios_build_number: 90,
        android_build_number: 84
      )

      get "/v1/admin/client/versions/#{version.id}", headers: headers

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs).to include(
        "number" => "1.4.0",
        "title" => "Force",
        "is_force_update" => true,
        "ios_build_number" => 90,
        "android_build_number" => 84,
        "install_count" => 0
      )
      expect(version_attrs).not_to have_key("must_update")
      expect(version_attrs).not_to have_key("update_required")
    end

    it "returns 404 for a missing version" do
      get "/v1/admin/client/versions/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response_status["message"]).to eq(I18n.t("version.not_found"))
    end
  end

  describe "POST /v1/admin/client/versions" do
    it "creates a draft version and localizes the message" do
      post "/v1/admin/client/versions",
           params: { version: { number: "2.0.0", title: "Next" } },
           headers: headers.merge("X-Locale" => "my"),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response_status["message"]).to eq(I18n.t("version.created", locale: :my))
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs).to include("number" => "2.0.0", "title" => "Next", "status" => "draft")
    end

    it "stamps released_at when creating as published" do
      post "/v1/admin/client/versions",
           params: { version: { number: "2.0.0", title: "Live", status: "published" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["status"]).to eq("published")
      expect(version_attrs["released_at"]).to be_present
    end

    it "yanks other published versions when creating as published" do
      previous = create(:version, :published, number: "1.0.0")
      draft = create(:version, number: "1.1.0")

      post "/v1/admin/client/versions",
           params: { version: { number: "2.0.0", title: "Live", status: "published" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(previous.reload.status).to eq(VersionConstants::Status::YANKED)
      expect(draft.reload.status).to eq(VersionConstants::Status::DRAFT)
      expect(Client::Version.where(status: VersionConstants::Status::PUBLISHED).count).to eq(1)
    end

    it "rejects an invalid semver" do
      post "/v1/admin/client/versions",
           params: { version: { number: "2.0", title: "Bad" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_status["message"]).to eq(I18n.t("version.create_failed"))
    end

    it "forbids a non-super-admin even with create_versions" do
      post "/v1/admin/client/versions",
           params: { version: { number: "2.0.0", title: "Next" } },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to eq(I18n.t("common.authorization.super_admin_required"))
      expect(Client::Version.count).to eq(0)
    end
  end

  describe "PUT /v1/admin/client/versions/:id" do
    it "updates version fields" do
      version = create(:version, number: "1.0.0", title: "Old")

      put "/v1/admin/client/versions/#{version.id}",
            params: { version: { title: "New", is_force_update: true } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs).to include("title" => "New", "is_force_update" => true)
    end

    it "yanks other published versions when a version is published" do
      previous = create(:version, :published, number: "1.0.0")
      version = create(:version, number: "1.1.0")

      put "/v1/admin/client/versions/#{version.id}",
            params: { version: { status: "published" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["status"]).to eq("published")
      expect(previous.reload.status).to eq(VersionConstants::Status::YANKED)
      expect(version.reload.status).to eq(VersionConstants::Status::PUBLISHED)
    end

    it "forbids a non-super-admin from updating" do
      version = create(:version, number: "1.0.0", title: "Old")

      put "/v1/admin/client/versions/#{version.id}",
            params: { version: { title: "New" } },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(version.reload.title).to eq("Old")
    end
  end

  describe "discard and restore" do
    it "hides discarded rows from the active list and returns them from the recycle bin" do
      active = create(:version, number: "1.0.0")
      discarded = create(:version, number: "0.9.0")
      discarded.discard!

      get "/v1/admin/client/versions", headers: headers

      expect(response_data.map { |record| record.dig("attributes", "id") }).to include(active.id)
      expect(response_data.map { |record| record.dig("attributes", "id") }).not_to include(discarded.id)

      get "/v1/admin/client/versions", params: { discarded: true }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("version.discarded_fetched"))
      expect(response_data.first.dig("attributes", "id")).to eq(discarded.id)
    end

    it "discards and restores a version" do
      version = create(:version, number: "1.0.0")

      post "/v1/admin/client/versions/#{version.id}/discard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("version.discarded"))
      expect(Client::Version.find_by(id: version.id)).to be_nil

      post "/v1/admin/client/versions/#{version.id}/undiscard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("version.restored"))
      expect(response_data["id"]).to eq(version.id)
      expect(Client::Version.find(version.id)).to be_kept
    end

    it "forbids a non-super-admin from discarding" do
      version = create(:version, number: "1.0.0")

      post "/v1/admin/client/versions/#{version.id}/discard", headers: admin_headers

      expect(response).to have_http_status(:forbidden)
      expect(Client::Version.find(version.id)).to be_kept
    end
  end

  describe "install_count" do
    it "returns the number of current snapshots linked to the version" do
      version = create(:version, :published, number: "1.4.0")
      other = create(:version, :yanked, number: "1.5.0")
      ios_user = create(:user)
      android_user = create(:user)

      ios_user.client_user_versions.create!(
        platform: AuthConstants::Platform::IOS,
        number: "1.4.0",
        version: version,
        last_seen_at: 2.hours.ago
      )
      android_user.client_user_versions.create!(
        platform: AuthConstants::Platform::ANDROID,
        number: "1.4.0",
        version: version,
        last_seen_at: 1.hour.ago
      )
      create(:user).client_user_versions.create!(
        platform: AuthConstants::Platform::WEB,
        number: "1.5.0",
        version: other,
        last_seen_at: Time.current
      )

      get "/v1/admin/client/versions", headers: headers

      listed = response_data.find { |record| record.dig("attributes", "id") == version.id }
      expect(listed.dig("attributes", "install_count")).to eq(2)

      get "/v1/admin/client/versions/#{version.id}", headers: headers

      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["install_count"]).to eq(2)
    end

    it "lists installs for a version newest first" do
      version = create(:version, :published, number: "1.4.0")
      older_user = create(:user, email: "older@example.com")
      newer_user = create(:user, email: "newer@example.com")
      older_user.client_user_versions.create!(
        platform: AuthConstants::Platform::IOS,
        number: "1.4.0",
        version: version,
        last_seen_at: 2.days.ago
      )
      newer_user.client_user_versions.create!(
        platform: AuthConstants::Platform::ANDROID,
        number: "1.4.0",
        version: version,
        last_seen_at: 1.hour.ago
      )

      get "/v1/admin/client/versions/#{version.id}/user_versions", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("user_version.fetched"))
      expect(response_data.size).to eq(2)
      expect(response_data.first.dig("attributes")).to include(
        "user_email" => "newer@example.com",
        "platform" => "android",
        "number" => "1.4.0"
      )
    end
  end
end
