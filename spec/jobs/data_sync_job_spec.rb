require "rails_helper"

RSpec.describe DataSyncJob, type: :job do
  describe "#perform" do
    it "invokes DataSyncService.sync_all! by default" do
      expect(DataSyncService).to receive(:sync_all!)

      described_class.perform_now
    end

    it "invokes DataSyncService.sync_all! when sync_type is 'all'" do
      expect(DataSyncService).to receive(:sync_all!)

      described_class.perform_now("all")
    end

    it "logs a warning when an unknown sync_type is supplied" do
      expect(Rails.logger).to receive(:warn).with(/Unknown or retired sync_type: unknown/)

      described_class.perform_now("unknown")
    end
  end
end
