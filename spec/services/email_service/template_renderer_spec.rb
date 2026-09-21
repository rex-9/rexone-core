# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailService::TemplateRenderer do
  describe ".render" do
    it "renders password_reset with button, escaped placeholder values, and brand shell" do
      html = described_class.render(
        "password_reset",
        email: "user@example.com",
        reset_url: "https://example.com/reset?token=<bad>"
      )

      expect(html).to include("Reset your passcode")
      expect(html).to include("user@example.com")
      expect(html).to include("https://example.com/reset?token=&lt;bad&gt;")
      expect(html).to include("REX<span style=\"color:#ffffff;\">ONE</span>")
      expect(html).to include("ALERT CENTER")
    end

    it "renders email_confirmation with prominent highlight code box" do
      html = described_class.render(
        "email_confirmation",
        email: "user@example.com",
        code: "987654"
      )

      expect(html).to include("Confirm your email")
      expect(html).to include("user@example.com")
      expect(html).to include("987654")
      expect(html).to include("letter-spacing:8px")
    end

    it "renders payment_purchase_confirmation with key-value details table" do
      html = described_class.render(
        "payment_purchase_confirmation",
        user_name: "Rex",
        product_name: "RexOne Pro Tier",
        amount: "$99.00",
        date: "September 21, 2026"
      )

      expect(html).to include("Payment successful")
      expect(html).to include("RexOne Pro Tier")
      expect(html).to include("$99.00")
      expect(html).to include("September 21, 2026")
      expect(html).to include("Amount")
      expect(html).to include("Date")
    end

    it "renders subscription lifecycle templates correctly" do
      sub_html = described_class.render(
        "payment_subscription_confirmation",
        user_name: "Rex",
        product_name: "Annual Plan",
        period: "annual",
        current_period_start: "Jan 1, 2026",
        current_period_end: "Dec 31, 2026"
      )
      expect(sub_html).to include("Subscription activated")
      expect(sub_html).to include("Annual Plan")
      expect(sub_html).to include("Jan 1, 2026 - Dec 31, 2026")

      cancel_html = described_class.render(
        "payment_subscription_canceled",
        user_name: "Rex",
        product_name: "Annual Plan",
        canceled_on: "Sep 21, 2026",
        valid_until: "Dec 31, 2026"
      )
      expect(cancel_html).to include("Subscription canceled")
      expect(cancel_html).to include("Sep 21, 2026")
      expect(cancel_html).to include("Dec 31, 2026")

      resume_html = described_class.render(
        "payment_subscription_resumed",
        user_name: "Rex",
        product_name: "Annual Plan",
        current_period_end: "Dec 31, 2026"
      )
      expect(resume_html).to include("Subscription resumed")
      expect(resume_html).to include("Dec 31, 2026")
    end

    it "renders security and welcome templates" do
      welcome_html = described_class.render("welcome", user_name: "Rex")
      expect(welcome_html).to include("Welcome to RexOne")
      expect(welcome_html).to include("Rex")

      alert_html = described_class.render("sign_in_alert", user_name: "Rex", time: "14:30 UTC")
      expect(alert_html).to include("New sign-in detected")
      expect(alert_html).to include("14:30 UTC")
    end

    it "returns nil for unknown templates" do
      expect(described_class.render("missing_template", {})).to be_nil
    end
  end

  describe ".render_content" do
    it "renders custom ad-hoc announcements or marketing campaigns without hardcodes" do
      html = described_class.render_content(
        title: "Exclusive 50% Off Launch Deal!",
        body: "Hi {{user_name}},\n\nTo celebrate our v2.0 launch, use this code for {{discount_percent}} off all subscriptions!",
        highlight: "LAUNCH50",
        cta_text: "Claim Your Discount",
        cta_url: "https://rexone.rex9.me/pricing?ref=<xss>",
        details: { "Discount" => "50% OFF", "Valid Until" => "Oct 1, 2026" },
        disclaimer: "Offer limited to the first 500 redemptions.",
        data: {
          user_name: "Rex",
          discount_percent: "50%"
        }
      )

      expect(html).to include("Exclusive 50% Off Launch Deal!")
      expect(html).to include("Hi Rex,")
      expect(html).to include("50% off all subscriptions!")
      expect(html).to include("LAUNCH50")
      expect(html).to include("Claim Your Discount")
      expect(html).to include("https://rexone.rex9.me/pricing?ref=&lt;xss&gt;")
      expect(html).to include("50% OFF")
      expect(html).to include("Oct 1, 2026")
      expect(html).to include("Offer limited to the first 500 redemptions.")
      expect(html).to include("&copy; 2026 RexOne Ecosystem")
    end

    it "escapes untrusted user input to prevent HTML injection" do
      html = described_class.render_content(
        title: "Alert: <script>alert(1)</script>",
        body: "Test message with <img src=x onerror=alert(2)/>",
        data: {}
      )

      expect(html).not_to include("<script>")
      expect(html).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
      expect(html).not_to include("<img")
      expect(html).to include("&lt;img src=x onerror=alert(2)/&gt;")
    end

    it "resolves relative links like /home against AppConfig.client_url" do
      html = described_class.render_content(
        title: "Welcome Back",
        body: "Check out your dashboard",
        cta_url: "/home",
        cta_text: "Go to Dashboard"
      )

      expected_url = "#{AppConfig::CLIENT_BASE_URL}/home"
      expect(html).to include("href=\"#{expected_url}\"")
      expect(html).to include(expected_url)
      expect(html).not_to include("href=\"/home\"")
    end
  end

  describe "relative URL resolution in templates" do
    it "resolves relative links in transactional templates via AppConfig.client_url" do
      html = described_class.render(
        "payment_failed",
        user_name: "Rex",
        product_name: "RexOne Pro",
        due_date: "Oct 1, 2026",
        link: "/payment"
      )

      expected_url = "#{AppConfig::CLIENT_BASE_URL}/payment"
      expect(html).to include("href=\"#{expected_url}\"")
      expect(html).to include(expected_url)
      expect(html).not_to include("href=\"/payment\"")
    end
  end

  describe ".subject" do
    it "resolves standard template subjects and custom overrides" do
      expect(described_class.subject("email_confirmation")).to eq("Confirm your RexOne email")
      expect(described_class.subject("email_confirmation", subject: "Custom Subject: {{code}}", code: "123")).to eq("Custom Subject: 123")
      expect(described_class.subject("custom_campaign_notice")).to eq("Custom Campaign Notice")
    end
  end
end
