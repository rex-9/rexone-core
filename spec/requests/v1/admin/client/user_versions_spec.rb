require "rails_helper"

RSpec.describe "V1 Admin User Versions API", type: :request do
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
    grant_admin_permissions(admin, IamConstants::Resource::CLIENT_USER_VERSIONS, :read)
    grant_super_admin_role(super_admin)
  end

  describe "GET /v1/admin/client/versions/user_versions" do
    it "lists all current user versions newest first" do
      version = create(:version, :published, number: "1.4.0")
      other = create(:version, :yanked, number: "1.5.0")
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
        number: "1.5.0",
        version: other,
        last_seen_at: 1.hour.ago
      )

      get "/v1/admin/client/versions/user_versions", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("user_version.fetched"))
      expect(response_data.size).to eq(2)
      expect(response_data.first.dig("attributes")).to include(
        "user_email" => "newer@example.com",
        "platform" => "android",
        "number" => "1.5.0"
      )
    end

    it "filters user versions by platform" do
      version = create(:version, :published, number: "1.4.0")
      create(:user).client_user_versions.create!(
        platform: AuthConstants::Platform::IOS,
        number: "1.4.0",
        version: version,
        last_seen_at: Time.current
      )
      create(:user).client_user_versions.create!(
        platform: AuthConstants::Platform::ANDROID,
        number: "1.4.0",
        version: version,
        last_seen_at: Time.current
      )

      get "/v1/admin/client/versions/user_versions", params: { platform: "ios" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "platform")).to eq("ios")
    end

    it "forbids a regular admin even with user_versions permissions" do
      get "/v1/admin/client/versions/user_versions", headers: admin_headers

      expect(response).to have_http_status(:forbidden)
      expect(response_status["error"]).to eq(I18n.t("common.authorization.super_admin_required"))
    end
  end
end
