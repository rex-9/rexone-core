require "rails_helper"

RSpec.describe NotificationService::Templates do
  it "keeps only admin notification template identifiers" do
    expect(described_class.constants(false)).to contain_exactly(
      :GENERAL_ANNOUNCEMENT,
      :MAINTENANCE_NOTICE,
      :FEATURE_UPDATE
    )
    expect(described_class.events).to contain_exactly(
      "general_announcement",
      "maintenance_notice",
      "feature_update"
    )
  end

  it "returns a catalog of admin-available notification events" do
    catalog = described_class.catalog
    expect(catalog).to be_an(Array)
    expect(catalog.size).to eq(3)
    expect(catalog).to all(include(:event, :label, :category, :admin_available))
    expect(catalog.first).to include(event: "general_announcement", admin_available: true, category: "broadcast")
  end

  it "identifies admin-available events" do
    expect(described_class.admin_available?("general_announcement")).to be(true)
    expect(described_class.admin_available?("maintenance_notice")).to be(true)
    expect(described_class.admin_available?("payment_failed")).to be(false)
    expect(described_class.admin_available?("nonexistent")).to be(false)
  end

  it "renders an event template with localized title and message" do
    result = described_class.render("general_announcement")
    expect(result).to include(:event, :title, :message, :email_template)
    expect(result[:event]).to eq("general_announcement")
    expect(result[:email_template]).to eq("general_announcement")
    expect(result[:title]).to be_a(String)
    expect(result[:message]).to be_a(String)
  end

  it "raises ArgumentError for unknown events" do
    expect { described_class.render("unknown_event") }.to raise_error(ArgumentError, /Unknown notification event/)
  end
end
