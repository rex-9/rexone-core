require "rails_helper"

RSpec.describe Payment::ProcessWebhookJob, type: :job do
  it "processes a persisted payload and marks it successful" do
    event = create(:payment_webhook_event)
    allow(PaymentService::Client).to receive(:process_webhook)

    described_class.perform_now(event.id)

    expect(PaymentService::Client).to have_received(:process_webhook).with(event.payload)
    expect(event.reload).to have_attributes(status: "processed", attempt_count: 1, last_error: nil)
  end

  it "is idempotent after successful processing" do
    event = create(:payment_webhook_event, status: "processed", processed_at: Time.current)
    allow(PaymentService::Client).to receive(:process_webhook)
    described_class.perform_now(event.id)
    expect(PaymentService::Client).not_to have_received(:process_webhook)
  end

  it "records failure and reraises so Active Job can retry" do
    event = create(:payment_webhook_event)
    allow(PaymentService::Client).to receive(:process_webhook).and_raise(RuntimeError, "processor failed")

    expect { described_class.perform_now(event.id) }.to raise_error(RuntimeError, "processor failed")
    expect(event.reload).to have_attributes(status: "failed", attempt_count: 1, last_error: "processor failed")
  end

  it "reraises a missing persisted event" do
    expect { described_class.perform_now(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
