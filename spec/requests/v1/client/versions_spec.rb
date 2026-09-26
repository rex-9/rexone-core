require "rails_helper"

RSpec.describe "V1 Versions API", type: :request do
  describe "GET /v1/client/versions/current" do
    it "returns an empty version payload without requiring authentication" do
      get "/v1/client/versions/current", params: { version: "1.0.0" }

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("version.current_fetched"))
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["number"]).to be_nil
      expect(version_attrs["update_required"]).to be(false)
      expect(version_attrs["must_update"]).to be(false)
      expect(version_attrs["skip_premium"]).to be(false)
      expect(Client::UserVersion.count).to eq(0)
    end

    it "returns the latest live release and computed update flags" do
      create(
        :version, :published, :force,
        number: "1.2.0",
        title: "Latest",
        ios_build_number: 90,
        android_build_number: 84
      )
      create(:version, number: "2.0.0", title: "Draft")
      create(:version, :yanked, number: "0.9.0", title: "Yanked")

      stub_const("AppConfig::IOS_STORE_URL", "https://apps.apple.com/app/rexone")

      get "/v1/client/versions/current",
          params: { version: "1.0.0" },
          headers: { "X-Platform" => AuthConstants::Platform::IOS }

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["number"]).to eq("1.2.0")
      expect(version_attrs["title"]).to eq("Latest")
      expect(version_attrs["update_required"]).to be(true)
      expect(version_attrs["must_update"]).to be(true)
      expect(version_attrs["skip_premium"]).to be(false)
      expect(version_attrs["store_url"]).to eq("https://apps.apple.com/app/rexone")
      expect(version_attrs).not_to have_key("is_force_update")
      expect(version_attrs).not_to have_key("ios_build_number")
      expect(version_attrs).not_to have_key("android_build_number")
      expect(Client::UserVersion.count).to eq(0)
    end

    it "does not require an update when the client is already on the latest live number" do
      create(:version, :published, number: "1.2.0")

      get "/v1/client/versions/current", params: { version: "1.2.0" }

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["update_required"]).to be(false)
      expect(version_attrs["must_update"]).to be(false)
      expect(version_attrs["skip_premium"]).to be(false)
    end

    it "marks update_required without must_update when the client is behind a non-force latest" do
      create(:version, :published, number: "1.2.0")

      get "/v1/client/versions/current", params: { version: "1.0.0" }

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["update_required"]).to be(true)
      expect(version_attrs["must_update"]).to be(false)
      expect(version_attrs["skip_premium"]).to be(false)
    end

    it "skips premium when the client marketing number is newer than the latest live release" do
      create(:version, :published, number: "1.2.0")
      create(:version, number: "2.0.0", title: "Draft")

      get "/v1/client/versions/current", params: { version: "1.3.0" }

      expect(response).to have_http_status(:ok)
      version_attrs = response_data["attributes"] || response_data
      expect(version_attrs["number"]).to eq("1.2.0")
      expect(version_attrs["update_required"]).to be(false)
      expect(version_attrs["must_update"]).to be(false)
      expect(version_attrs["skip_premium"]).to be(true)
    end

    it "does not write a Client::UserVersion even with a valid JWT" do
      user = create(:user)
      grant_permissions(user, "versions", :read)

      get "/v1/client/versions/current",
          params: { version: "1.4.0" },
          headers: authorization_headers(jwt_for(user))

      expect(response).to have_http_status(:ok)
      expect(Client::UserVersion.count).to eq(0)
    end

    it "allows a signed-in user with read_versions" do
      user = create(:user)
      grant_permissions(user, "versions", :read)

      get "/v1/client/versions/current",
          params: { version: "1.0.0" },
          headers: authorization_headers(jwt_for(user))

      expect(response).to have_http_status(:ok)
    end

    it "forbids a signed-in user without read_versions" do
      user = create(:user)
      user.user_roles.destroy_all

      get "/v1/client/versions/current",
          params: { version: "1.0.0" },
          headers: authorization_headers(jwt_for(user))

      expect(response).to have_http_status(:forbidden)
    end

    it "ignores an invalid bearer token and still returns the check" do
      get "/v1/client/versions/current",
          params: { version: "1.0.0" },
          headers: { "Authorization" => "Bearer not-a-jwt" }

      expect(response).to have_http_status(:ok)
      expect(Client::UserVersion.count).to eq(0)
    end
  end
end
