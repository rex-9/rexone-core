require "rails_helper"

RSpec.describe Notification::DispatchJob, type: :job do
  let!(:first_user) { create(:user) }
  let!(:second_user) { create(:user) }
  let(:teacher_role) { create(:role, name: "teacher") }
  let(:admin_role) { create(:role, name: "admin") }

  before do
    allow(NotificationService).to receive(:notify)
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

    expect(NotificationService).to have_received(:notify).once.with(
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

    expect(NotificationService).to have_received(:notify).twice
    expect(NotificationService).to have_received(:notify).with(
      hash_including(user_id: first_user.id, send_push: true, send_socket: false, send_email: false)
    )
    expect(NotificationService).to have_received(:notify).with(
      hash_including(user_id: second_user.id, send_push: true, send_socket: false, send_email: false)
    )
  end

  it "fans selected users out through the requested delivery channels" do
    described_class.perform_now(
      audience: { type: "users", user_ids: [ second_user.id ] },
      channels: %w[socket],
      event: "general_announcement"
    )

    expect(NotificationService).to have_received(:notify).once.with(
      hash_including(user_id: second_user.id, send_socket: true, send_push: false, send_email: false)
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

    expect(NotificationService).not_to have_received(:notify)
  end
end
