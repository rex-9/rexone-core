require "rails_helper"

RSpec.describe "Google authentication", type: :request do
  before do
    allow(NotificationService::Center).to receive(:sign_in_alert)
    allow(NotificationService::Center).to receive(:welcome)
    allow(CacheService).to receive(:write)
    allow(CacheService).to receive(:delete)
    allow(StorageService::Client).to receive(:upload) do |_file, options|
      {
        storage_key: "avatar/#{options[:storage_key]}",
        url: "https://cdn.example.com/#{options[:storage_key]}.jpg",
        bytes: 1234,
        format: "jpg",
        resource_type: "image"
      }
    end
  end

  describe "POST /signin/google" do
    it "signs in an existing account returned by Google" do
      user = create(:user, :google_provider, email: "google@example.com")
      stub_google_token(email: user.email, name: user.name)

      post "/signin/google", params: { token: "google-token" }
      expect(response).to have_http_status(:ok)
      expect(response_data.dig("user", "id")).to eq(user.id)
      expect(NotificationService::Center).to have_received(:sign_in_alert)
    end

    it "uploads a Google avatar when the existing account only has a Google image URL" do
      user = create(:user, :google_provider, email: "google@example.com")
      create(
        :asset,
        source: AssetConstants::AssetSource::GOOGLE,
        storage_key: nil,
        assetable_type: "user",
        assetable_id: user.id,
        url: "https://lh3.googleusercontent.com/stale-avatar"
      )
      stub_google_token(email: user.email, name: user.name, picture: "https://example.com/avatar.jpg")

      post "/signin/google", params: { token: "google-token" }

      expect(response).to have_http_status(:ok)
      expect(user.reload.get_avatar_url).to eq("https://example.com/avatar.jpg")
      expect(StorageService::Client).to have_received(:upload).with(
        "https://example.com/avatar.jpg",
        hash_including(
          storage_key: AssetConstants::AssetName.google_profile(user.id),
          folder: "user_uploads/#{AssetConstants::AssetType::AVATAR}",
          resource_type: AssetConstants::AssetFormat::IMAGE
        )
      )
    end

    it "rejects a discarded account returned by Google" do
      user = create(:user, :google_provider, email: "google@example.com")
      user.discard!
      stub_google_token(email: user.email, name: user.name)

      post "/signin/google", params: { token: "google-token" }

      expect(response).to have_http_status(:forbidden)
      expect(response_status["message"]).to eq(I18n.t("auth.account_discarded"))
      expect(response_status["error"]).to eq(I18n.t("auth.account_discarded"))
      expect(CacheService).not_to have_received(:write)
    end

    it "stores a short-lived challenge for a new account" do
      stub_google_token(email: "new.google@example.com", name: "Google User", picture: "https://example.com/avatar.jpg")
      allow(SecureRandom).to receive(:urlsafe_base64).and_return("challenge-token")

      post "/signin/google", params: { token: "google-token" }
      expect(response).to have_http_status(:ok)
      expect(response_data).to include("password_required" => true, "challenge_token" => "challenge-token")
      expect(CacheService).to have_received(:write).with(
        "google_signin:challenge:challenge-token",
        include('"email":"new.google@example.com"'),
        expires_in: 5.minutes
      )
    end

    it "rejects a missing or invalid Google token or network error" do
      post "/signin/google", params: {}
      expect(response).to have_http_status(:unauthorized)

      allow(RestClient::Request).to receive(:execute).and_raise(RestClient::ExceptionWithResponse)
      post "/signin/google", params: { token: "invalid" }
      expect(response).to have_http_status(:unauthorized)

      allow(RestClient::Request).to receive(:execute).and_raise(Errno::ENETUNREACH, "Network is unreachable")
      post "/signin/google", params: { token: "network_fail" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /signin/google/complete" do
    let(:challenge) do
      { email: "new.user@example.com", name: "New Google User", picture: "https://example.com/avatar.jpg" }.to_json
    end

    it "requires both challenge and password" do
      post "/signin/google/complete", params: { challenge_token: "challenge" }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects missing, expired, or malformed challenge data" do
      allow(CacheService).to receive(:read).and_return(nil, "not-json")

      2.times do
        post "/signin/google/complete", params: { challenge_token: "challenge", password: "password123" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "creates a confirmed Google account, session, and welcome notification" do
      create(:role, name: "user")
      allow(CacheService).to receive(:read).and_return(challenge)

      expect do
        post "/signin/google/complete", params: { challenge_token: "challenge", password: "password123" }
      end.to change(User, :count).by(1)

      user = User.find_by!(email: "new.user@example.com")
      expect(response).to have_http_status(:created)
      expect(user).to be_confirmed
      expect(user).to have_attributes(username: "new_user", provider: "google")
      expect(user.assets.find_by(type: AssetConstants::AssetType::AVATAR)).to have_attributes(
        name: a_string_starting_with("users/#{user.id}/avatar_google_"),
        url: "https://example.com/avatar.jpg",
        format: AssetConstants::AssetFormat::IMAGE,
        source: AssetConstants::AssetSource::GOOGLE
      )
      expect(StorageService::Client).to have_received(:upload).with(
        "https://example.com/avatar.jpg",
        hash_including(
          storage_key: AssetConstants::AssetName.google_profile(user.id),
          folder: "user_uploads/#{AssetConstants::AssetType::AVATAR}",
          resource_type: AssetConstants::AssetFormat::IMAGE
        )
      )
      expect(NotificationService::Center).to have_received(:welcome).with(user_id: user.id, name: user.name)
      expect(CacheService).to have_received(:delete).with("google_signin:challenge:challenge")
    end

    it "adds a suffix when the sanitized username is already taken" do
      create(:user, username: "new_user")
      allow(CacheService).to receive(:read).and_return(challenge)
      allow(SecureRandom).to receive(:random_number).and_call_original
      allow(SecureRandom).to receive(:random_number).with(10**6).and_return(42)

      post "/signin/google/complete", params: { challenge_token: "challenge", password: "password123" }
      expect(response).to have_http_status(:created)
      expect(User.find_by!(email: "new.user@example.com").username).to eq("new_user_000042")
    end

    it "completes an existing account created during an outstanding challenge" do
      user = create(:user, email: "new.user@example.com")
      allow(CacheService).to receive(:read).and_return(challenge)

      expect do
        post "/signin/google/complete", params: { challenge_token: "challenge", password: "ignored-password" }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
      expect(user.reload).to be_confirmed
      expect(user.provider).to eq("google")
      expect(response_data.dig("user", "id")).to eq(user.id)
      expect(response_data["token"]).to be_present
      expect(NotificationService::Center).to have_received(:welcome).with(user_id: user.id, name: "New Google User")
      expect(CacheService).to have_received(:delete).with("google_signin:challenge:challenge")
    end

    it "completes with the existing account when duplicate challenge submits race" do
      create(:role, name: "user")
      user = build(:user, email: "new.user@example.com")
      allow(CacheService).to receive(:read).and_return(challenge)
      allow_any_instance_of(User).to receive(:save).and_wrap_original do |original, *args|
        record = original.receiver

        if !record.persisted? && record.email == "new.user@example.com"
          user.save!
          raise ActiveRecord::RecordNotUnique
        end

        original.call(*args)
      end

      expect do
        post "/signin/google/complete", params: { challenge_token: "challenge", password: "password123" }
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("user", "id")).to eq(user.id)
      expect(response_data["token"]).to be_present
    end

    it "rejects an account discarded while its challenge was outstanding" do
      user = create(:user, email: "new.user@example.com")
      user.discard!
      allow(CacheService).to receive(:read).and_return(challenge)

      post "/signin/google/complete", params: { challenge_token: "challenge", password: "password123" }

      expect(response).to have_http_status(:forbidden)
      expect(response_status["message"]).to eq(I18n.t("auth.account_discarded"))
      expect(response_status["error"]).to eq(I18n.t("auth.account_discarded"))
      expect(CacheService).not_to have_received(:write)
    end

    it "keeps a valid challenge when account validation fails" do
      allow(CacheService).to receive(:read).and_return(challenge)
      post "/signin/google/complete", params: { challenge_token: "challenge", password: "short" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(CacheService).not_to have_received(:delete)
    end
  end

  def stub_google_token(email:, name:, picture: nil)
    response = instance_double(RestClient::Response, body: { email: email, name: name, picture: picture }.to_json)
    allow(RestClient::Request).to receive(:execute).and_return(response)
  end
end
