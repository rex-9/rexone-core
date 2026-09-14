require "rails_helper"

RSpec.describe EmailService::Client do
  it "uses Brevo as the default email provider" do
    stub_const("AppConfig::EMAIL_PROVIDER", "brevo")

    allow(EmailService::Brevo).to receive(:new).and_return(instance_double(EmailService::Brevo, send_email: true))

    described_class.send_email(to: "user@example.com", subject: "Hi", body: "Body")

    expect(EmailService::Brevo).to have_received(:new)
  end

  it "can switch to the OneSignal email provider" do
    stub_const("AppConfig::EMAIL_PROVIDER", "one_signal")

    allow(EmailService::OneSignal).to receive(:new).and_return(instance_double(EmailService::OneSignal, send_email: true))

    described_class.send_email(to: "user@example.com", subject: "Hi", body: "Body")

    expect(EmailService::OneSignal).to have_received(:new)
  end

  it "rejects unknown email providers" do
    stub_const("AppConfig::EMAIL_PROVIDER", "unknown")

    expect do
      described_class.send_email(to: "user@example.com", subject: "Hi", body: "Body")
    end.to raise_error(EmailService::Error, "Unknown email provider: unknown")
  end
end
