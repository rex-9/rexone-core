require "rails_helper"

RSpec.describe Payment::WebhookEvent, type: :model do
  it "validates persisted event identity and payload" do
    expect(build(:payment_webhook_event)).to be_valid
    expect(build(:payment_webhook_event, stripe_event_id: nil)).not_to be_valid
    expect(build(:payment_webhook_event, payload: {})).not_to be_valid
    expect(build(:payment_webhook_event, attempt_count: -1)).not_to be_valid
  end

  it "tracks processing attempts, success, and failure" do
    event = create(:payment_webhook_event, last_error: "old")
    event.start_processing!
    expect(event).to have_attributes(status: "processing", attempt_count: 1, last_error: nil)
    expect(event.processing_started_at).to be_present

    event.mark_as_failed!(RuntimeError.new("boom"))
    expect(event).to have_attributes(status: "failed", last_error: "boom")
    event.start_processing!
    event.mark_as_processed!
    expect(event).to have_attributes(status: "processed", attempt_count: 2, last_error: nil)
    expect(event.processed_at).to be_present
  end

  it "returns pending and failed events as retryable" do
    pending_event = create(:payment_webhook_event)
    failed_event = create(:payment_webhook_event, status: "failed")
    create(:payment_webhook_event, status: "processed", processed_at: Time.current)
    expect(described_class.retryable).to contain_exactly(pending_event, failed_event)
  end

  it "cleans only processed and failed events beyond retention" do
    old_processed = create(:payment_webhook_event, status: "processed", processed_at: 31.days.ago)
    recent_processed = create(:payment_webhook_event, status: "processed", processed_at: 1.day.ago)
    old_failed = create(:payment_webhook_event, status: "failed", updated_at: 181.days.ago)
    recent_failed = create(:payment_webhook_event, status: "failed")

    expect(described_class.cleanup_old!).to eq(processed_deleted: 1, failed_deleted: 1)
    expect(described_class.where(id: [ old_processed.id, old_failed.id ])).to be_empty
    expect(described_class.where(id: [ recent_processed.id, recent_failed.id ]).count).to eq(2)
  end
end
