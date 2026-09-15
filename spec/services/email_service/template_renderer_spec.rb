require "rails_helper"

RSpec.describe EmailService::TemplateRenderer do
  it "renders provider-agnostic templates with escaped placeholder values" do
    html = described_class.render(
      "password_reset",
      email: "user@example.com",
      reset_url: "https://example.com/reset?token=<bad>"
    )

    expect(html).to include("Reset your passcode")
    expect(html).to include("user@example.com")
    expect(html).to include("https://example.com/reset?token=&lt;bad&gt;")
  end

  it "returns nil for unknown templates" do
    expect(described_class.render("missing_template", {})).to be_nil
  end
end
