# frozen_string_literal: true

# ==============================================================================
# RexOne Security Boot Guard
# Enforces production cryptographic hygiene & provides development diagnostics.
# ==============================================================================

module SecurityBootGuard
  CRITICAL_KEYS = {
    "RAILS_SECRET_KEY_BASE" => {
      placeholders: [ "secret-key-base", "change-me", "your_secret_key_base" ],
      min_length: 32,
      description: "Rails session and cookie encryption key"
    },
    "RAILS_JWT_SECRET_KEY" => {
      placeholders: [ "rexone", "secret", "change-me", "your_jwt_secret" ],
      min_length: 16,
      description: "JWT authentication signature key"
    },
    "PG_PASSWORD" => {
      placeholders: [ "password", "postgres", "admin", "123456" ],
      min_length: 8,
      description: "PostgreSQL database password"
    },
    "S3_ADMIN_TOKEN" => {
      placeholders: [ "rexone_garage_admin_token_secret_key_12345" ],
      min_length: 16,
      description: "Garage S3 storage administration token"
    }
  }.freeze

  INTEGRATION_KEYS = {
    "BREVO_API_KEY" => {
      placeholders: [ "your_brevo_api_key_here", "brevo_key_xxx" ],
      feature: "Transactional Email Service (Brevo)",
      impact: "User account confirmation codes and password reset emails will not be sent."
    },
    "STRIPE_SECRET_KEY" => {
      placeholders: [ "sk_test_xxx", "sk_live_xxx", "your_stripe_secret_key" ],
      feature: "Stripe Payments & Billing",
      impact: "Checkout sessions, payment intents, and customer subscriptions will fail."
    },
    "DEEPSEEK_API_KEY" => {
      placeholders: [ "sk-xxx", "your_deepseek_api_key" ],
      feature: "DeepSeek AI Engine",
      impact: "DeepSeek LLM completions will fail."
    },
    "GEMINI_API_KEY" => {
      placeholders: [ "AIzaSyxxx", "your_gemini_api_key" ],
      feature: "Google Gemini AI Engine",
      impact: "Gemini multimodal and text completions will fail."
    },
    "ONE_SIGNAL_API_KEY" => {
      placeholders: [ "your_onesignal_api_key", "xxx" ],
      feature: "OneSignal Push Notifications",
      impact: "Push notifications will not be delivered to mobile and web subscribers."
    },
    "AZURE_SPEECH_KEY" => {
      placeholders: [ "your_azure_speech_key" ],
      feature: "Azure Speech Live Streaming",
      impact: "Real-time WebSocket speech-to-text is disabled (Nova HTTP STT remains active)."
    }
  }.freeze

  class << self
    def check!(env = Rails.env)
      return if env.test? && ENV["TEST_BOOT_GUARD"] != "true"

      critical_violations = find_critical_violations
      integration_warnings = find_integration_warnings

      if env.production? || ENV["ENFORCE_BOOT_GUARD"] == "true"
        handle_production!(critical_violations, integration_warnings)
      else
        handle_development(integration_warnings)
      end
    end

    def find_critical_violations
      violations = []

      CRITICAL_KEYS.each do |key, rules|
        val = ENV[key].to_s.strip

        if val.empty?
          violations << { key: key, reason: "is BLANK or MISSING", description: rules[:description] }
        elsif rules[:placeholders].include?(val)
          violations << { key: key, reason: "matches insecure default placeholder '#{val}'", description: rules[:description] }
        elsif rules[:min_length] && val.length < rules[:min_length]
          violations << { key: key, reason: "is too short (#{val.length} chars; minimum #{rules[:min_length]} chars required)", description: rules[:description] }
        end
      end

      violations
    end

    def find_integration_warnings
      warnings = []

      INTEGRATION_KEYS.each do |key, rules|
        val = ENV[key].to_s.strip

        if val.empty?
          warnings << { key: key, status: "Missing (Blank)", feature: rules[:feature], impact: rules[:impact] }
        elsif rules[:placeholders].any? { |p| val == p || val.include?(p) }
          warnings << { key: key, status: "Dummy Placeholder", feature: rules[:feature], impact: rules[:impact] }
        end
      end

      warnings
    end

    private

    def handle_production!(critical_violations, integration_warnings)
      if critical_violations.any?
        banner = [
          "",
          "======================================================================",
          "  🚨 FATAL SECURITY BOOT GUARD VIOLATION (Production Aborted)",
          "======================================================================",
          "RexOne refused to boot because critical production secrets are insecure:",
          ""
        ]

        critical_violations.each do |v|
          banner << "  ❌ #{v[:key]}: #{v[:reason]}"
          banner << "     Description: #{v[:description]}"
        end

        banner += [
          "",
          "  🔧 REMEDY:",
          "  Run './scripts/generate_secrets.sh' to generate high-entropy random keys,",
          "  then set them in your production .env or environment secret manager.",
          "======================================================================",
          ""
        ]

        abort(banner.join("\n"))
      end

      if integration_warnings.any?
        Rails.logger.warn("[SecurityBootGuard] Production notice: #{integration_warnings.size} optional integrations have dummy or missing keys.")
      end
    end

    def handle_development(warnings)
      return if warnings.empty? || ENV["QUIET_BOOT"] == "true"

      # Print clean diagnostics in development console
      puts ""
      puts "┌──────────────────────────────────────────────────────────────────────────┐"
      puts "│  🔍 RexOne Development Environment Diagnostics                           │"
      puts "├──────────────────────────────────────────────────────────────────────────┤"
      warnings.each do |w|
        puts "│  ⚠️  #{w[:key].ljust(22)} [#{w[:status]}]".ljust(75) + "│"
        puts "│      Feature: #{w[:feature]}".ljust(75) + "│"
        puts "│      Notice : #{w[:impact]}".ljust(75) + "│"
      end
      puts "└──────────────────────────────────────────────────────────────────────────┘"
      puts ""
    end
  end
end

SecurityBootGuard.check!
