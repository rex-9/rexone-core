require "rails_helper"

RSpec.describe AssetsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/assets").to route_to("assets#index")
    end

    it "routes to #show" do
      expect(get: "/assets/1").to route_to("assets#show", id: "1")
    end


    it "routes to #create" do
      expect(post: "/assets").to route_to("assets#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/assets/1").to route_to("assets#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/assets/1").to route_to("assets#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/assets/1").to route_to("assets#destroy", id: "1")
    end
  end
end
