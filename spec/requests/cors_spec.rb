# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS Policy", type: :request do
  let(:test_path) { "/up" }

  def check_cors(origin)
    reset!
    options test_path, headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "GET"
    }
  end

  describe "Allowed origins" do
    it "allows local development origins" do
      check_cors("http://localhost:4000")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:4000")

      check_cors("http://127.0.0.1:4000")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://127.0.0.1:4000")
    end

    it "allows Demo tier with http, https, and www (rexone.rex9.me, www.rexone.rex9.me)" do
      check_cors("https://rexone.rex9.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://rexone.rex9.me")

      check_cors("http://rexone.rex9.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://rexone.rex9.me")

      check_cors("https://www.rexone.rex9.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://www.rexone.rex9.me")

      check_cors("http://www.rexone.rex9.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://www.rexone.rex9.me")
    end

    it "allows product tier with http, https, and www when PRODUCT_DOMAIN is configured (e.g. rexone.me: prod, uat, dev, www)" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PRODUCT_DOMAIN").and_return("rexone.me")

      check_cors("https://rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://rexone.me")

      check_cors("http://rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://rexone.me")

      check_cors("https://www.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://www.rexone.me")

      check_cors("https://uat.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://uat.rexone.me")

      check_cors("http://uat.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://uat.rexone.me")

      check_cors("https://www.uat.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://www.uat.rexone.me")

      check_cors("https://dev.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://dev.rexone.me")

      check_cors("http://dev.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://dev.rexone.me")

      check_cors("https://www.dev.rexone.me")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://www.dev.rexone.me")
    end

    it "dynamically allows custom PRODUCT_DOMAIN with any TLD (e.g. .com, .io, .ai)" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PRODUCT_DOMAIN").and_return("nexuspay.io")

      check_cors("https://nexuspay.io")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://nexuspay.io")

      check_cors("https://uat.nexuspay.io")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://uat.nexuspay.io")

      check_cors("https://dev.nexuspay.io")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://dev.nexuspay.io")
    end

    it "dynamically allows custom CORS_ORIGINS list" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("CORS_ORIGINS").and_return("https://partner-portal.com, https://admin.internal.net")

      check_cors("https://partner-portal.com")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://partner-portal.com")

      check_cors("https://admin.internal.net")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://admin.internal.net")
    end

    it "rejects unauthorized arbitrary origins" do
      check_cors("https://untrusted-attacker.com")
      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end
end
