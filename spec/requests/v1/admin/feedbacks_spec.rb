require "rails_helper"

RSpec.describe "V1 Admin Feedbacks API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_permissions(admin, "feedbacks", :read, :update, :delete)
  end

  describe "GET /v1/admin/feedbacks" do
    it "returns all paginated feedbacks for admin" do
      create_list(:feedback, 3)

      get "/v1/admin/feedbacks", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

    it "filters feedbacks by status and category" do
      create(:feedback, status: FeedbackConstants::Status::NEW, category: FeedbackConstants::Category::BUG)
      create(:feedback, status: FeedbackConstants::Status::RESOLVED, category: FeedbackConstants::Category::IMPROVEMENT)

      get "/v1/admin/feedbacks", params: { status: "new", category: "bug" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "category")).to eq("bug")
    end
  end

  describe "GET /v1/admin/feedbacks/:id" do
    it "returns feedback details" do
      feedback = create(:feedback, content: "Admin inspectable item")

      get "/v1/admin/feedbacks/#{feedback.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "content")).to eq("Admin inspectable item")
    end
  end

  describe "PATCH /v1/admin/feedbacks/:id" do
    it "updates feedback status and admin notes" do
      feedback = create(:feedback, status: FeedbackConstants::Status::NEW)

      patch "/v1/admin/feedbacks/#{feedback.id}", params: {
        feedback: {
          status: FeedbackConstants::Status::RESOLVED,
          admin_notes: "Fixed in release v1.2"
        }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "status")).to eq("resolved")
      expect(response_data.dig("attributes", "admin_notes")).to eq("Fixed in release v1.2")
    end
  end

  describe "DELETE /v1/admin/feedbacks/:id" do
    it "soft-deletes the feedback" do
      feedback = create(:feedback)

      delete "/v1/admin/feedbacks/#{feedback.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(feedback.reload.discarded_at).to be_present
    end
  end
end
