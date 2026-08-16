require "rails_helper"

RSpec.describe "Stripe webhooks", type: :request do
  let(:payload) { { id: "evt_test", type: "checkout.session.completed", data: { object: {} } }.to_json }
  let(:event) do
    instance_double(
      Stripe::Event,
      id: "evt_test",
      type: "checkout.session.completed",
      livemode: false
    )
  end

  before do
    allow(PaymentService::Client).to receive(:verify_webhook).and_return(event)
    allow(PaymentService::Client).to receive(:supported_webhook_event?).and_return(true)
  end

  it "verifies, persists, and queues a supported event" do
    expect do
      post "/webhooks/stripe", params: payload, headers: { "Stripe-Signature" => "signature", "CONTENT_TYPE" => "application/json" }
    end.to change(Payment::WebhookEvent, :count).by(1).and have_enqueued_job(Payment::ProcessWebhookJob)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("received" => true, "event_id" => "evt_test", "status" => "queued")
    expect(PaymentService::Client).to have_received(:verify_webhook).with(payload, "signature")
  end

  it "acknowledges unsupported events without persistence or queueing" do
    allow(PaymentService::Client).to receive(:supported_webhook_event?).and_return(false)
    post "/webhooks/stripe", params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["status"]).to eq("ignored")
    expect(Payment::WebhookEvent.count).to eq(0)
    expect(Payment::ProcessWebhookJob).not_to have_been_enqueued
  end

  it "does not requeue an already processed duplicate" do
    create(:payment_webhook_event, stripe_event_id: "evt_test", status: "processed", processed_at: Time.current)
    post "/webhooks/stripe", params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["status"]).to eq("already_processed")
    expect(Payment::ProcessWebhookJob).not_to have_been_enqueued
  end

  it "returns bad request for an invalid signature" do
    error = Stripe::SignatureVerificationError.new("bad signature", "header")
    allow(PaymentService::Client).to receive(:verify_webhook).and_raise(error)
    post "/webhooks/stripe", params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)["received"]).to be(false)
  end

  it "asks Stripe to retry when queueing fails" do
    allow(Payment::ProcessWebhookJob).to receive(:perform_later).and_raise(SolidQueue::Job::EnqueueError.new("queue down"))
    post "/webhooks/stripe", params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:service_unavailable)
    expect(Payment::WebhookEvent.find_by(stripe_event_id: "evt_test")).to be_present
  end
end
