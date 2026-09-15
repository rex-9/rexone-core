require "rails_helper"

RSpec.describe "V1 Admin AI Runs API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, IamConstants::Resource::AI_RUNS, :read)
  end

  describe "Authorization & Permissions" do
    let(:unprivileged_user) { create(:user) }
    let(:unprivileged_token) { jwt_for(unprivileged_user) }
    let(:unprivileged_headers) { authorization_headers(unprivileged_token) }

    before do
      allow(CacheService).to receive(:read).with(any_args).and_return(unprivileged_token)
    end

    it "requires authentication" do
      get "/v1/admin/ai/runs"
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids non-admin users even with permission" do
      grant_permissions(unprivileged_user, IamConstants::Resource::AI_RUNS, :read)
      get "/v1/admin/ai/runs", headers: unprivileged_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids admin users without ai_runs:read permission" do
      admin_without_perm = create(:user)
      admin_token = jwt_for(admin_without_perm)
      allow(CacheService).to receive(:read).with(any_args).and_return(admin_token)
      grant_admin_role(admin_without_perm)

      get "/v1/admin/ai/runs", headers: authorization_headers(admin_token)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /v1/admin/ai/runs" do
    it "returns paginated telemetry runs" do
      create_list(:ai_run, 3)

      get "/v1/admin/ai/runs", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

    it "filters runs by status and feature" do
      create(:ai_run, feature: AiConstants::RunFeature::CHAT, status: AiConstants::RunStatus::COMPLETED)
      create(:ai_run, feature: AiConstants::RunFeature::ANALYZE, status: AiConstants::RunStatus::FAILED)

      get "/v1/admin/ai/runs",
          params: { feature: AiConstants::RunFeature::CHAT, status: AiConstants::RunStatus::COMPLETED },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "feature")).to eq(AiConstants::RunFeature::CHAT)
    end

    it "filters runs by provider and model" do
      create(:ai_run, provider: "deepseek", model: "deepseek-chat")
      create(:ai_run, provider: "gemini", model: "gemini-2.5-flash")

      get "/v1/admin/ai/runs", params: { provider: "gemini", model: "gemini-2.5-flash" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "provider")).to eq("gemini")
      expect(response_data.first.dig("attributes", "model")).to eq("gemini-2.5-flash")
    end

    it "filters runs by search term" do
      create(:ai_run, feature: "chat", model: "deepseek-chat")
      create(:ai_run, feature: "summarize", model: "gemini-2.5-pro")

      get "/v1/admin/ai/runs", params: { search: "summarize" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "feature")).to eq("summarize")
    end

    it "sorts runs by latency_ms ascending" do
      create(:ai_run, latency_ms: 100)
      create(:ai_run, latency_ms: 900)

      get "/v1/admin/ai/runs", params: { sort_by: "latency_ms", sort_order: "asc" }, headers: headers

      expect(response).to have_http_status(:ok)
      latencies = response_data.map { |r| r.dig("attributes", "latency_ms") }
      expect(latencies.first).to eq(100)
      expect(latencies.last).to eq(900)
    end
  end

  describe "GET /v1/admin/ai/runs/:id" do
    it "returns run details" do
      run = create(:ai_run, status: AiConstants::RunStatus::COMPLETED, latency_ms: 250)

      get "/v1/admin/ai/runs/#{run.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "latency_ms")).to eq(250)
    end

    it "returns 404 when run is not found" do
      get "/v1/admin/ai/runs/00000000-0000-0000-0000-000000000000", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
