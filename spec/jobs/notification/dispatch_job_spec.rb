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
      title: "Release",
      message: "The new release is ready.",
      data: { "path" => "/releases" }
    )

    expect(NotificationService).to have_received(:notify).once.with(
      user_id: first_user.id,
      user_email: first_user.email,
      title: "Release",
      message: "The new release is ready.",
      data: { "path" => "/releases" },
      send_socket: true,
      send_push: false,
      send_email: true
    )
  end

  it "fans an all-user audience out without embedding user ids in the job" do
    described_class.perform_now(
      audience: { type: "all" },
      channels: %w[push],
      title: "News",
      message: "Something new",
      data: {}
    )

    expect(NotificationService).to have_received(:notify).twice
    expect(NotificationService).to have_received(:notify).with(
      hash_including(user_id: first_user.id, send_push: true, send_socket: false, send_email: false)
    )
    expect(NotificationService).to have_received(:notify).with(
      hash_including(user_id: second_user.id, send_push: true, send_socket: false, send_email: false)
    )
  end

  it "does not target unconfirmed accounts" do
    unconfirmed = create(:user, :unconfirmed)
    create(:user_role, user: unconfirmed, role: teacher_role)

    described_class.perform_now(
      audience: { type: "roles", role_ids: [ teacher_role.id ] },
      channels: %w[email],
      title: "News",
      message: "Something new",
      data: {}
    )

    expect(NotificationService).not_to have_received(:notify)
  end
end
