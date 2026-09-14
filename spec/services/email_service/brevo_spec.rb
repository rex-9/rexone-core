require "rails_helper"

RSpec.describe EmailService::Brevo do
  before do
    stub_const("AppConfig::BREVO_API_KEY", "brevo-key")
    stub_const("AppConfig::BREVO_BASE_URL", "https://api.brevo.com/v3")
    stub_const("AppConfig::FROM_EMAIL", "support@rexone.me")
  end

  subject(:provider) { described_class.new }

  it "sends a plain transactional email through Brevo" do
    response = double("RestClient::Response", body: { messageId: "message-id" }.to_json)

    expect(RestClient).to receive(:post).with(
      "https://api.brevo.com/v3/smtp/email",
      {
        sender: { email: "support@rexone.me" },
        to: [ { email: "user@example.com" } ],
        subject: "Welcome",
        htmlContent: "<p>Hello</p>"
      }.to_json,
      {
        content_type: :json,
        accept: :json,
        "api-key": "brevo-key"
      }
    ).and_return(response)

    expect(provider.send_email(to: "user@example.com", subject: "Welcome", body: "<p>Hello</p>")).to eq("messageId" => "message-id")
  end

  it "sends a numeric Brevo template id with params" do
    response = double("RestClient::Response", body: { messageId: "message-id" }.to_json)

    expect(RestClient).to receive(:post).with(
      "https://api.brevo.com/v3/smtp/email",
      {
        sender: { email: "support@rexone.me" },
        to: [ { email: "user@example.com" } ],
        templateId: 42,
        params: { code: "123456" }
      }.to_json,
      hash_including("api-key": "brevo-key")
    ).and_return(response)

    provider.send_template(to: "user@example.com", template_id: "42", template_data: { code: "123456" })
  end

  it "falls back to plain HTML when an existing symbolic template name is used" do
    allow(RestClient).to receive(:post).and_return(double("RestClient::Response", body: "{}"))

    provider.send_template(
      to: "user@example.com",
      template_id: "payment_purchase_confirmation",
      template_data: { product_name: "Monthly", amount: "USD 10.00" }
    )

    expect(RestClient).to have_received(:post) do |url, body, headers|
      payload = JSON.parse(body)

      expect(url).to eq("https://api.brevo.com/v3/smtp/email")
      expect(headers).to include("api-key": "brevo-key")
      expect(payload).to include("subject" => "Payment confirmation")
      expect(payload["htmlContent"]).to include("Payment successful")
      expect(payload["htmlContent"]).to include("Monthly")
      expect(payload["htmlContent"]).to include("USD 10.00")
    end
  end

  it "is disabled when no Brevo API key is configured" do
    stub_const("AppConfig::BREVO_API_KEY", "")

    expect(described_class.new.send_email(to: "user@example.com", subject: "Hi", body: "Body")).to eq("disabled" => true)
  end

  it "wraps provider errors without exposing response internals to callers" do
    allow(RestClient).to receive(:post).and_raise(RestClient::Exception.new)

    expect do
      provider.send_email(to: "user@example.com", subject: "Hi", body: "Body")
    end.to raise_error(EmailService::Error, /Failed to send email/)
  end
end
