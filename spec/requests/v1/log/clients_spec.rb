require "rails_helper"

RSpec.describe "V1 Log Clients API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "clients", :read, :create, :update, :delete)
  end

  describe "POST /v1/log/clients" do
    it "creates a new client log unauthenticated" do
      expect do
        post "/v1/log/clients",
             params: {
               log: {
                 message: "TypeError: Cannot read property",
                 severity: "error",
                 platform: "web",
                 environment: "production"
               }
             }
      end.to change(Log::Client, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response_data).to include("id")
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
        post "/v1/log/clients",
             params: {
               log: {
                 message: "Duplicated error",
                 severity: "error",
                 platform: "web",
                 environment: "development"
               }
             }
      end.not_to change(Log::Client, :count)

      expect(response).to have_http_status(:ok)
      expect(log.reload.occurrence_count).to eq(2)
    end
  end

  describe "GET /v1/log/clients" do
    it "returns paginated logs" do
      create_list(:log_client, 3)

      get "/v1/log/clients", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/log/clients/:id" do
    let(:log) { create(:log_client) }

    it "returns the log client details" do
      get "/v1/log/clients/#{log.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "message")).to eq(log.message)
    end
  end

  describe "PUT /v1/log/clients/:id/resolve" do
    let(:log) { create(:log_client) }

    it "marks the log as resolved" do
      put "/v1/log/clients/#{log.id}/resolve", headers: headers

      expect(response).to have_http_status(:ok)
      expect(log.reload.resolved?).to be true
      expect(log.resolved_by).to eq(user)
    end
  end

  describe "PUT /v1/log/clients/:id/unresolve" do
    let(:log) { create(:log_client, resolved_at: Time.current, resolved_by: user) }

    it "unresolves the log" do
      put "/v1/log/clients/#{log.id}/unresolve", headers: headers

      expect(response).to have_http_status(:ok)
      expect(log.reload.resolved?).to be false
    end
  end

  describe "DELETE /v1/log/clients/:id" do
    let!(:log) { create(:log_client) }

    it "destroys the log record" do
      expect do
        delete "/v1/log/clients/#{log.id}", headers: headers
      end.to change(Log::Client, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
