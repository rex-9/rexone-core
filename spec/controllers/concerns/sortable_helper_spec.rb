# frozen_string_literal: true

require "rails_helper"

RSpec.describe SortableHelper, type: :controller do
  controller(ApplicationController) do
    include SortableHelper
    skip_before_action :authenticate_user!
    skip_before_action :enforce_active_platform_session!

    def index
      users = sort(
        User.all,
        columns: SortConstants::Columns::USER
      )
      render json: { users: users.map(&:name) }
    end
  end

  let!(:user_a) { create(:user, name: "Alice", email: "alice@example.com", username: "alice_user") }
  let!(:user_b) { create(:user, name: "Bob", email: "bob@example.com", username: "bob_user") }
  let!(:user_z) { create(:user, name: "Zack", email: "zack@example.com", username: "zack_user") }

  describe "#sort" do
    it "sorts by whitelisted column ascending" do
      get :index, params: { sort_by: "name", sort_order: "asc" }
      json = JSON.parse(response.body)
      expect(json["users"]).to eq([ "Alice", "Bob", "Zack" ])
    end

    it "sorts by whitelisted column descending when using desc" do
      get :index, params: { sort_by: "name", sort_order: "desc" }
      json = JSON.parse(response.body)
      expect(json["users"]).to eq([ "Zack", "Bob", "Alice" ])
    end

    it "falls back to default column and direction when non-whitelisted column is requested" do
      get :index, params: { sort_by: "sql_injection_attempt; DROP TABLE users;", sort_order: "asc" }
      expect(response).to have_http_status(:ok)
    end
  end
end
