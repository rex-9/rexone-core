require "rails_helper"

RSpec.describe Notification::DispatchJob, type: :job do
  let!(:first_user) { create(:user) }
  let!(:second_user) { create(:user) }
  let(:teacher_role) { create(:role, name: "teacher") }
  let(:admin_role) { create(:role, name: "admin") }

  let!(:announcement) do
    create(:notification,
      event: "general_announcement",
      name: "Announcement",
      in_app_title: "Announcement",
      in_app_body: "We have an important announcement for you.",
      push_title: "Announcement",
      push_body: "We have an important announcement for you.",
      email_subject: "Announcement",
      email_body: "We have an important announcement for you."
    )
  end

  let!(:feature_update) do
    create(:notification,
      event: "feature_update",
      name: "New Feature",
      in_app_title: "New Feature",
      in_app_body: "A new feature is available.",
      push_title: "New Feature",
      push_body: "A new feature is available."
    )
  end

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
      template_id: announcement.id,
      title: "Announcement",
      message: "We have an important announcement for you.",
      push_title: "Announcement",
      push_body: "We have an important announcement for you.",
      link: nil,
      data: { type: "general_announcement" },
      push_template_id: nil,
      email_template: nil,
      email_template_data: {
        title: "Announcement",
        message: "We have an important announcement for you.",
        subject: "Announcement",
        body: "We have an important announcement for you.",
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

  it "enqueues in-app notification delivery with message and persists user notification" do
    allow(NotificationService::Center).to receive(:notify).and_call_original

    expect {
      described_class.perform_now(
        audience: { type: "users", user_ids: [ second_user.id ] },
        channels: %w[socket],
        event: "general_announcement",
        locale: "en"
      )
    }.to change { second_user.user_notifications.count }.by(1)

    created_notification = second_user.user_notifications.last

    expect(Notification::DeliverJob).to have_been_enqueued.with(
      channel: :socket,
      payload: hash_including(
        user_id: second_user.id,
        id: created_notification.id,
        title: "Announcement",
        message: "We have an important announcement for you.",
        data: { "type" => "general_announcement" }
      )
    )
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
