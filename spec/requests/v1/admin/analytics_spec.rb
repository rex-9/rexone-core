# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1 Admin Analytics API", type: :request do
  let(:admin) { create(:user, :super_admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_super_admin_role(admin)
  end

  describe "GET /v1/admin/analytics/overview" do
    it "returns analytics overview for super admin" do
      create(:user)

      get "/v1/admin/analytics/overview", params: { period: "30d" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["period"]).to eq("30d")
      expect(response_data["kpis"]).to be_present
      expect(response_data["time_series"]).to be_an(Array)
    end

    it "allows admins with analytics read permission" do
      standard_admin = create(:user)
      admin_token = jwt_for(standard_admin)
      allow(CacheService).to receive(:read).and_return(admin_token)
      grant_admin_permissions(standard_admin, "analytics", :read)

      get "/v1/admin/analytics/overview", headers: authorization_headers(admin_token)

      expect(response).to have_http_status(:ok)
    end

    it "rejects unauthorized non-admin users" do
      normal_user = create(:user)
      user_token = jwt_for(normal_user)
      allow(CacheService).to receive(:read).and_return(user_token)

      get "/v1/admin/analytics/overview", headers: authorization_headers(user_token)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
