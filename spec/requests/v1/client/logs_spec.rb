require "rails_helper"

RSpec.describe "V1 Client Logs API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "logs", :read, :create, :update, :delete)
  end

  describe "POST /v1/client/logs" do
    it "creates a new client log unauthenticated" do
      expect do
        post "/v1/client/logs",
             params: {
               log: {
                 message: "TypeError: Cannot read property",
                 severity: "error",
                 platform: "web",
                 environment: "production"
               }
             }
      end.to change(Client::Log, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response_data).to include("id")
    end

    it "links version_id when app_version matches a kept version" do
      version = create(:version, number: "1.4.0")

      post "/v1/client/logs",
           params: {
             log: {
               message: "TypeError: Cannot read property",
               severity: "error",
               platform: "web",
               environment: "production",
               app_version: "1.4.0"
             }
           }

      expect(response).to have_http_status(:created)
      log = Client::Log.find(response_data["id"])
      expect(log.version_id).to eq(version.id)

      get "/v1/client/logs/#{log.id}", headers: headers

      expect(response_data.dig("attributes", "version_id")).to eq(version.id)
      expect(response_data.dig("attributes", "app_version")).to eq("1.4.0")
    end

    it "leaves version_id null when app_version is unknown" do
      post "/v1/client/logs",
           params: {
             log: {
               message: "Unknown version crash",
               severity: "error",
               platform: "web",
               environment: "production",
               app_version: "9.9.9"
             }
           }

      expect(response).to have_http_status(:created)
      expect(Client::Log.find(response_data["id"]).version_id).to be_nil
    end

    it "leaves version_id null when app_version is omitted" do
      post "/v1/client/logs",
           params: {
             log: {
               message: "Missing version crash",
               severity: "error",
               platform: "web",
               environment: "production"
             }
           }

      expect(response).to have_http_status(:created)
      expect(Client::Log.find(response_data["id"]).version_id).to be_nil
    end

    it "stores and strictly types metadata" do
      post "/v1/client/logs",
           params: {
             log: {
               message: "Crash in checkout",
               severity: "error",
               platform: "web",
               environment: "production",
               metadata: {
                 component: "CheckoutModal",
                 action: "pay",
                 attempt: 2
               }
             }
           }

      expect(response).to have_http_status(:created)
      log = Client::Log.find(response_data["id"])
      expect(log.metadata.component).to eq("CheckoutModal")
      expect(log.metadata.action).to eq("pay")
      expect(log.metadata.attempt).to eq(2)
    end

    it "rejects unrecognized rogue keys in metadata" do
      post "/v1/client/logs",
           params: {
             log: {
               message: "Rogue crash",
               severity: "error",
               platform: "web",
               environment: "production",
               metadata: {
                 rogue_key: "forbidden"
               }
             }
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("status", "error")).to include("unrecognized metadata key")
    end

    it "increments occurrence count for identical existing logs" do
      log = create(
        :log_client,
        message: "Duplicated error",
        severity: "error",
        platform: "web",
        environment: "development"
      )

      expect do
        post "/v1/client/logs",
             params: {
               log: {
                 message: "Duplicated error",
                 severity: "error",
                 platform: "web",
                 environment: "development"
               }
             }
      end.not_to change(Client::Log, :count)

      expect(response).to have_http_status(:ok)
      expect(log.reload.occurrence_count).to eq(2)
    end
  end

  describe "GET /v1/client/logs" do
    it "returns paginated logs" do
      create_list(:log_client, 3)

      get "/v1/client/logs", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/client/logs/:id" do
    let(:log) { create(:log_client) }

    it "returns the log client details" do
      get "/v1/client/logs/#{log.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "message")).to eq(log.message)
    end
  end

  describe "PUT /v1/client/logs/:id/resolve" do
    let(:log) { create(:log_client) }

    it "marks the log as resolved" do
      put "/v1/client/logs/#{log.id}/resolve", headers: headers

      expect(response).to have_http_status(:ok)
      expect(log.reload.resolved?).to be true
      expect(log.resolved_by).to eq(user)
    end
  end

  describe "PUT /v1/client/logs/:id/unresolve" do
    let(:log) { create(:log_client, resolved_at: Time.current, resolved_by: user) }

    it "unresolves the log" do
      put "/v1/client/logs/#{log.id}/unresolve", headers: headers

      expect(response).to have_http_status(:ok)
      expect(log.reload.resolved?).to be false
    end
  end

  describe "DELETE /v1/client/logs/:id" do
    let!(:log) { create(:log_client) }

    it "destroys the log record" do
      expect do
        delete "/v1/client/logs/#{log.id}", headers: headers
      end.to change(Client::Log, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
