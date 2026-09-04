require "rails_helper"

RSpec.describe Notification::DispatchJob, type: :job do
  let!(:first_user) { create(:user) }
  let!(:second_user) { create(:user) }
  let(:teacher_role) { create(:role, name: "teacher") }
  let(:admin_role) { create(:role, name: "admin") }

  before do
    allow(NotificationService::Center).to receive(:notify)
  end

  it "fans selected roles out through the requested delivery channels without duplicates" do
    create(:user_role, user: first_user, role: teacher_role)
    create(:user_role, user: first_user, role: admin_role)

    described_class.perform_now(
      audience: { type: "roles", role_ids: [ teacher_role.id, admin_role.id ] },
      channels: %w[socket email],
      event: "general_announcement",
      locale: "en"
    )

    expect(NotificationService::Center).to have_received(:notify).once.with(
      user_id: first_user.id,
      user_email: first_user.email,
      title: "Announcement",
      message: "We have an important announcement for you.",
      data: { type: "general_announcement" },
      email_template: NotificationService::Templates::GENERAL_ANNOUNCEMENT,
      email_template_data: {
        event: "general_announcement",
        title: "Announcement",
        message: "We have an important announcement for you.",
        user_name: first_user.name || first_user.username
      },
      send_socket: true,
      send_push: false,
      send_email: true
    )
  end

  it "fans an all-user audience out without embedding user ids in the job" do
    described_class.perform_now(
      audience: { type: "all" },
      channels: %w[push],
      event: "feature_update"
    )

    expect(NotificationService::Center).to have_received(:notify).twice
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(user_id: first_user.id, send_push: true, send_socket: false, send_email: false)
    )
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(user_id: second_user.id, send_push: true, send_socket: false, send_email: false)
    )
  end

  it "fans selected users out through the requested delivery channels" do
    described_class.perform_now(
      audience: { type: "users", user_ids: [ second_user.id ] },
      channels: %w[socket],
      event: "general_announcement"
    )

    expect(NotificationService::Center).to have_received(:notify).once.with(
      hash_including(user_id: second_user.id, send_socket: true, send_push: false, send_email: false)
    )
  end

  it "enqueues in-app notification delivery with message" do
    allow(NotificationService::Center).to receive(:notify).and_call_original

    expect do
      described_class.perform_now(
        audience: { type: "users", user_ids: [ second_user.id ] },
        channels: %w[socket],
        event: "general_announcement",
        locale: "en"
      )
    end.to change(Notification, :count).by(1)

    notification = Notification.last

    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :socket,
      payload: {
        user_id: second_user.id,
        id: notification.id,
        title: "Announcement",
        message: "We have an important announcement for you.",
        data: { "type" => "general_announcement" },
        created_at: notification.created_at.iso8601
      }
    )
  end

  it "does not persist push-only notifications as in-app records" do
    allow(NotificationService::Center).to receive(:notify).and_call_original

    expect do
      described_class.perform_now(
        audience: { type: "users", user_ids: [ second_user.id ] },
        channels: %w[push],
        event: "general_announcement",
        locale: "en"
      )
    end.not_to change(Notification, :count)
  end

  it "does not target unconfirmed accounts" do
    unconfirmed = create(:user, :unconfirmed)
    create(:user_role, user: unconfirmed, role: teacher_role)

    described_class.perform_now(
      audience: { type: "roles", role_ids: [ teacher_role.id ] },
      channels: %w[email],
      event: "general_announcement"
    )

    expect(NotificationService::Center).not_to have_received(:notify)
  end
end
