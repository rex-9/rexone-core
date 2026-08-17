require "rails_helper"

RSpec.describe NotificationService do
  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  it "enqueues only explicitly requested channels" do
    result = described_class.notify_all(
      user_id: "user-id", title: "Title", message: "Message",
      data: { type: "custom" }, send_socket: true, send_push: false, send_email: false
    )

    expect(result).to eq(socket: true)
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :socket,
      payload: { user_id: "user-id", message: "Message", data: { type: "custom" } }
    )
  end

  it "does not enqueue push without a title" do
    expect do
      described_class.notify_all(user_id: "user-id", message: "Body", send_push: true)
    end.not_to have_enqueued_job(Notification::DeliverJob)
  end

  it "resolves an email address lazily and applies plain defaults" do
    user = create(:user)
    described_class.notify_all(user_id: user.id, send_email: true)
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :email,
      payload: hash_including(to: user.email, subject: be_present, body: be_present)
    )
  end

  it "builds template email payloads" do
    described_class.notify_all(
      user_id: "user-id", user_email: "user@example.com", send_email: true,
      email_template: "template", email_template_data: { code: "123456" }
    )
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :email,
      payload: { to: "user@example.com", template_id: "template", template_data: { code: "123456" } }
    )
  end

  it "returns false instead of interrupting the caller when enqueueing fails" do
    allow(Notification::DeliverJob).to receive(:perform_later).and_raise("queue unavailable")
    expect(described_class.email(email: "user@example.com", subject: "Hi", body: "Body")).to be(false)
  end

  it "creates confirmation and password-reset email jobs" do
    described_class.confirmation_email(email: "user@example.com", code: "123456")
    described_class.password_reset_email(email: "user@example.com", token: "token")
    expect(Notification::DeliverJob).to have_been_enqueued.exactly(:twice)
  end

  it "fans payment success out to socket, push, and template email" do
    user = create(:user)
    product = create(:payment_product)
    transaction = create(:payment_transaction, user: user, product: product, paid_at: Time.current)
    described_class.payment_success(user, product, transaction)
    expect(Notification::DeliverJob).to have_been_enqueued.exactly(:thrice)
  end
end
