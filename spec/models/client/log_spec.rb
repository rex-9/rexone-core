require "rails_helper"

RSpec.describe Client::Log, type: :model do
  describe "typed metadata" do
    it "coerces and exposes typed metadata attributes" do
      log = described_class.new(
        message: "Test error",
        severity: "error",
        metadata: {
          "app_version" => "1.0.0",
          "component" => "AuthProvider",
          "action" => "login",
          "endpoint" => "/v1/auth/login",
          "attempt" => "3",
          "user_id" => "u123",
          "status_code" => "401",
          "error_type" => "UnauthorizedError"
        }
      )

      expect(log.metadata.app_version).to eq("1.0.0")
      expect(log.metadata.component).to eq("AuthProvider")
      expect(log.metadata.action).to eq("login")
      expect(log.metadata.endpoint).to eq("/v1/auth/login")
      expect(log.metadata.attempt).to eq(3)
      expect(log.metadata.user_id).to eq("u123")
      expect(log.metadata.status_code).to eq(401)
      expect(log.metadata.error_type).to eq("UnauthorizedError")
    end

    it "rejects invalid rogue keys" do
      log = described_class.new(
        message: "Test error",
        severity: "error",
        metadata: { "unknown_rogue_field" => "bad" }
      )

      expect(log).not_to be_valid
      expect(log.errors[:metadata].first).to include("unrecognized metadata key")
    end
  end
end
