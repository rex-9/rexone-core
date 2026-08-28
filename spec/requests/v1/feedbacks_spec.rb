require "rails_helper"

RSpec.describe "V1 Feedbacks API", type: :request do
  let(:user) { create(:user) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_permissions(user, "feedbacks", :create, :read)
  end

  describe "POST /v1/feedbacks" do
    it "creates feedback anonymously when unauthenticated" do
      post "/v1/feedbacks", params: {
        feedback: {
          content: "The app crashed when I clicked checkout!",
          rating: 2,
          page: "/checkout"
        }
      }

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "category")).to eq(FeedbackConstants::Category::BUG)
      expect(response_data.dig("attributes", "priority")).to eq(FeedbackConstants::Priority::HIGH)
      expect(response_data.dig("attributes", "user_id")).to be_nil
    end

    it "creates feedback and associates the current user when authenticated" do
      post "/v1/feedbacks", params: {
        feedback: {
          content: "Could you please add dark mode support?",
          rating: 8,
          page: "/settings"
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "category")).to eq(FeedbackConstants::Category::FEATURE_REQUEST)
      expect(response_data.dig("attributes", "user_id")).to eq(user.id)
      expect(response_data.dig("attributes", "user_name")).to eq(user.name)
    end

    it "rejects blank feedback content" do
      post "/v1/feedbacks", params: {
        feedback: {
          content: "",
          rating: 5
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /v1/feedbacks" do
    it "returns paginated feedbacks belonging to the current user" do
      3.times { create(:feedback, user: user) }
      create(:feedback, user: create(:user))

      get "/v1/feedbacks", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "GET /v1/feedbacks/:id" do
    it "returns the feedback item if owned by the user" do
      feedback = create(:feedback, user: user, content: "Loved the speed!")

      get "/v1/feedbacks/#{feedback.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "content")).to eq("Loved the speed!")
    end

    it "returns 404 for feedback belonging to another user" do
      other_feedback = create(:feedback, user: create(:user))

      get "/v1/feedbacks/#{other_feedback.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
