# frozen_string_literal: true

require "rails_helper"

RSpec.describe SecurityBootGuard do
  describe ".find_critical_violations" do
    it "detects blank critical keys" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RAILS_SECRET_KEY_BASE").and_return("")

      violations = described_class.find_critical_violations
      secret_base_violation = violations.find { |v| v[:key] == "RAILS_SECRET_KEY_BASE" }

      expect(secret_base_violation).not_to be_nil
      expect(secret_base_violation[:reason]).to include("BLANK or MISSING")
    end

    it "detects placeholder keys matching .env.example" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RAILS_JWT_SECRET_KEY").and_return("rexone")

      violations = described_class.find_critical_violations
      jwt_violation = violations.find { |v| v[:key] == "RAILS_JWT_SECRET_KEY" }

      expect(jwt_violation).not_to be_nil
      expect(jwt_violation[:reason]).to include("matches insecure default placeholder 'rexone'")
    end

    it "detects keys that are too short for security requirements" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RAILS_SECRET_KEY_BASE").and_return("short-secret-key-12345")

      violations = described_class.find_critical_violations
      secret_base_violation = violations.find { |v| v[:key] == "RAILS_SECRET_KEY_BASE" }

      expect(secret_base_violation).not_to be_nil
      expect(secret_base_violation[:reason]).to include("too short")
    end

    it "returns no violations when all critical keys are high-entropy" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RAILS_SECRET_KEY_BASE").and_return(SecureRandom.hex(32))
      allow(ENV).to receive(:[]).with("RAILS_JWT_SECRET_KEY").and_return(SecureRandom.hex(16))
      allow(ENV).to receive(:[]).with("PG_PASSWORD").and_return("super_secret_db_pass_123456")
      allow(ENV).to receive(:[]).with("S3_ADMIN_TOKEN").and_return(SecureRandom.hex(16))

      violations = described_class.find_critical_violations
      expect(violations).to be_empty
    end
  end

  describe ".find_integration_warnings" do
    it "identifies missing and dummy external integration keys" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("BREVO_API_KEY").and_return("your_brevo_api_key_here")
      allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return("sk_test_xxx")

      warnings = described_class.find_integration_warnings
      brevo = warnings.find { |w| w[:key] == "BREVO_API_KEY" }
      stripe = warnings.find { |w| w[:key] == "STRIPE_SECRET_KEY" }

      expect(brevo).not_to be_nil
      expect(brevo[:status]).to eq("Dummy Placeholder")
      expect(stripe).not_to be_nil
      expect(stripe[:status]).to eq("Dummy Placeholder")
    end
  end

  describe ".check!" do
    it "aborts in production when critical violations exist" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RAILS_JWT_SECRET_KEY").and_return("rexone")

      prod_env = ActiveSupport::StringInquirer.new("production")
      expect { described_class.check!(prod_env) }.to raise_error(SystemExit)
    end
  end
end
