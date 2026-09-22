require "rails_helper"

RSpec.describe NotificationService::Center do
  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  it "enqueues only explicitly requested channels" do
    result = described_class.notify(
      user_id: "user-id", title: "Title", message: "Message",
      data: { type: "custom" }, send_socket: true, send_push: false, send_email: false
    )

    expect(result).to eq(socket: true)
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :socket,
      payload: {
        user_id: "user-id",
        message: "Message",
        clients: NotificationConstants::Client::DEFAULT,
        data: { type: "custom" }
      }
    )
  end

  it "does not enqueue push without a title" do
    expect do
      described_class.notify(user_id: "user-id", message: "Body", send_push: true)
    end.not_to have_enqueued_job(Notification::DeliverJob)
  end

  it "keeps admin portal operations on Web and does not send a mobile push" do
    user = create(:user)

    described_class.notify(
      user_id: user.id,
      title: "Asset ready",
      message: "Asset ready",
      link: "/admin/assets/asset-id",
      send_socket: true,
      send_push: true
    )

    expect(user.user_notifications.last.clients).to eq(NotificationConstants::Client::ADMIN_PORTAL)
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :socket,
      payload: hash_including(clients: NotificationConstants::Client::ADMIN_PORTAL)
    )
    expect(Notification::DeliverJob).not_to have_been_enqueued.with(channel: :push, payload: anything)
  end

  it "persists every push and sends its user notification id to the client" do
    user = create(:user)

    expect do
      described_class.notify(
        user_id: user.id,
        title: "Title",
        message: "Body",
        send_push: true
      )
    end.to change(user.user_notifications, :count).by(1)

    notification = user.user_notifications.last
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :push,
      payload: hash_including(
        data: hash_including(
          AnalyticsConstants::Parameter::NOTIFICATION_ID => notification.id
        )
      )
    )
  end

  it "resolves an email address lazily and applies plain defaults" do
    user = create(:user)
    described_class.notify(user_id: user.id, send_email: true)
    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :email,
      payload: hash_including(to: user.email, subject: be_present, body: be_present)
    )
  end

  it "builds template email payloads" do
    described_class.notify(
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

  it "updates one persisted notification throughout an async operation lifecycle" do
    user = create(:user)
    attributes = {
      user_id: user.id,
      operation_id: "ai_response:message-id",
      operation_type: NotificationConstants::OperationType::AI_RESPONSE,
      link: "/ai?room_id=room-id",
      message: "Working"
    }

    described_class.operation(
      **attributes,
      operation_status: NotificationConstants::OperationStatus::PROCESSING
    )
    described_class.operation(
      **attributes.merge(message: "Ready"),
      operation_status: NotificationConstants::OperationStatus::COMPLETED
    )

    expect(user.user_notifications.count).to eq(1)
    expect(user.user_notifications.first).to have_attributes(
      message: "Ready",
      operation_status: NotificationConstants::OperationStatus::COMPLETED,
      link: "/ai?room_id=room-id"
    )
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

  it "fans subscription created out to socket, push, and template email" do
    user = create(:user)
    product = create(:payment_product)
    subscription = create(:payment_subscription, user: user, product: product)
    described_class.subscription_created(user, product, subscription)
    expect(Notification::DeliverJob).to have_been_enqueued.exactly(:thrice)
  end

  it "fans subscription canceled out to socket, push, and template email" do
    user = create(:user)
    product = create(:payment_product)
    subscription = create(:payment_subscription, user: user, product: product, canceled_at: Time.current)
    described_class.subscription_canceled(user, product, subscription)
    expect(Notification::DeliverJob).to have_been_enqueued.exactly(:thrice)
  end

  it "fans subscription resumed out to socket, push, and template email" do
    user = create(:user)
    product = create(:payment_product)
    subscription = create(:payment_subscription, user: user, product: product)
    described_class.subscription_resumed(user, product, subscription)
    expect(Notification::DeliverJob).to have_been_enqueued.exactly(:thrice)
  end

  it "fans payment failed out to socket, push, and template email" do
    user = create(:user)
    product = create(:payment_product)
    subscription = create(:payment_subscription, user: user, product: product)
    described_class.payment_failed(user, product, subscription)
    expect(Notification::DeliverJob).to have_been_enqueued.exactly(:thrice)
  end

  describe ".welcome" do
    let(:user) { create(:user) }

    it "creates a welcome notification for new users" do
      expect do
        described_class.welcome(user)
      end.to change(user.user_notifications, :count).by(1)
    end

    it "delivers an HTTPS link configured on the template" do
      external_link = "https://example.com/welcome"
      create(
        :notification,
        event: NotificationConstants::NotificationType::WELCOME,
        link: external_link
      )

      described_class.welcome(user)

      expect(Notification::DeliverJob).to have_been_enqueued.with(
        channel: :socket,
        payload: hash_including(link: external_link)
      )
    end

    it "safely returns if user is nil" do
      expect do
        described_class.welcome("non-existent-id")
      end.not_to raise_error
    end
  end
end
