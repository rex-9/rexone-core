require "rails_helper"

RSpec.describe "V1 User Versions API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token, platform: AuthConstants::Platform::ANDROID) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "user_versions", :create)
  end

  describe "POST /v1/client/versions/user-version" do
    it "requires authentication" do
      post "/v1/client/versions/user-version", params: { user_version: { version: "1.4.0" } }

      expect(response).to have_http_status(:unauthorized)
      expect(Client::UserVersion.count).to eq(0)
    end

    it "creates a Client::UserVersion for the current user and platform" do
      version = create(:version, :published, number: "1.4.0")

      post "/v1/client/versions/user-version",
           params: { user_version: { version: "1.4.0", version_code: 42 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response_status["message"]).to eq(I18n.t("user_version.created"))
      record = user.client_user_versions.find_by!(platform: AuthConstants::Platform::ANDROID)
      expect(record).to have_attributes(
        number: "1.4.0",
        build_number: 42,
        version_id: version.id
      )
      expect(response_data.dig("attributes", "number")).to eq("1.4.0")
      expect(response_data.dig("attributes", "build_number")).to eq(42)
    end

    it "updates the existing user version for the same user and platform" do
      version = create(:version, :published, number: "1.5.0")
      existing = user.client_user_versions.create!(
        platform: AuthConstants::Platform::ANDROID,
        number: "1.4.0",
        build_number: 10,
        last_seen_at: 1.day.ago
      )

      post "/v1/client/versions/user-version",
           params: { user_version: { version: "1.5.0", version_code: 50 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response_status["message"]).to eq(I18n.t("user_version.updated"))
      expect(user.client_user_versions.count).to eq(1)
      expect(existing.reload).to have_attributes(
        number: "1.5.0",
        build_number: 50,
        version_id: version.id
      )
    end

    it "requires create_user_versions" do
      user.user_roles.destroy_all
      create(:version, :published, number: "1.4.0")

      post "/v1/client/versions/user-version",
           params: { user_version: { version: "1.4.0" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Client::UserVersion.count).to eq(0)
    end

    it "rejects an invalid marketing number" do
      post "/v1/client/versions/user-version",
           params: { user_version: { version: "not-a-version" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Client::UserVersion.count).to eq(0)
    end
  end
end
