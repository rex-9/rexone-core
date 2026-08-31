require "rails_helper"

RSpec.describe "V1 Admin Users API", type: :request do
  let(:admin) { create(:user, :super_admin) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_super_admin_role(admin)
  end

  describe "GET /v1/admin/users" do
    it "returns paginated users list for super admin" do
      create_list(:user, 3)

      get "/v1/admin/users", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "limit")).to eq(2)
    end

    it "searches users by username, name, and email" do
      username_match = create(:user, username: "needle_user", name: "Other", email: "other@example.com")
      name_match = create(:user, username: "other_user", name: "Needle Name", email: "name@example.com")
      email_match = create(:user, username: "email_user", name: "Email", email: "email.needle@example.com")
      create(:user, username: "ignored_user", name: "Ignored", email: "ignored@example.com")

      get "/v1/admin/users", params: { search: "needle" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.map { |record| record.dig("attributes", "id") }).to contain_exactly(
        username_match.id,
        name_match.id,
        email_match.id
      )
    end 
     
    it "rejects standard admin users" do
      standard_admin = create(:user)
      admin_token = jwt_for(standard_admin)
      allow(CacheService).to receive(:read).and_return(admin_token)
      grant_admin_role(standard_admin)

      get "/v1/admin/users", headers: authorization_headers(admin_token)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects non-admin users" do
      normal_user = create(:user)
      user_token = jwt_for(normal_user)
      allow(CacheService).to receive(:read).and_return(user_token)
      grant_permissions(normal_user, "users", :read)

      get "/v1/admin/users", headers: authorization_headers(user_token)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects partial admins who only hold non-user admin roles like feedback_admin" do
      partial_admin = create(:user)
      token = jwt_for(partial_admin)
      allow(CacheService).to receive(:read).and_return(token)

      # User has user role with read_users, and feedback_admin role with read_feedbacks
      grant_permissions(partial_admin, "users", :read, admin: false)
      grant_admin_permissions(partial_admin, "feedbacks", :read)

      get "/v1/admin/users", headers: authorization_headers(token)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
