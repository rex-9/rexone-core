require "rails_helper"

RSpec.describe DataSyncService do
  describe ".sync_all!" do
    it "runs all sync routines and returns a summary hash with synced_at timestamp" do
      result = described_class.sync_all!

      expect(result[:synced_at]).to be_present
    end

    it "does not overwrite or reduce cumulative notification sent_count or read_count" do
      notification = create(:notification, event: "promo_lifetime", sent_count: 50, read_count: 30)

      described_class.sync_all!

      notification.reload
      expect(notification.sent_count).to eq(50)
      expect(notification.read_count).to eq(30)
    end
  end
end
