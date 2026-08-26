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
end
