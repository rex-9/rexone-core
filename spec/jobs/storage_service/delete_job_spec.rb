require "rails_helper"

RSpec.describe StorageService::DeleteJob, type: :job do
  it "symbolizes options and delegates deletion" do
    allow(StorageService::Client).to receive(:delete).and_return(true)
    described_class.perform_now(identifier: "profile/avatar", options: { "resource_type" => "image" })
    expect(StorageService::Client).to have_received(:delete).with("profile/avatar", resource_type: "image")
  end

  it "schedules retries for storage errors" do
    allow(StorageService::Client).to receive(:delete).and_raise(StorageService::Error, "offline")
    expect do
      described_class.perform_now(identifier: "profile/avatar")
    end.to have_enqueued_job(described_class).with(identifier: "profile/avatar")
  end
end
