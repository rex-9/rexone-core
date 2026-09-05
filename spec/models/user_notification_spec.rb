require "rails_helper"

RSpec.describe UserNotification, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "is valid with valid attributes" do
      notification = build(:user_notification, user: user)
      expect(notification).to be_valid
    end

    it "requires title and message" do
      expect(build(:user_notification, user: user, title: nil)).not_to be_valid
      expect(build(:user_notification, user: user, message: nil)).not_to be_valid
    end
  end

  describe "scopes and methods" do
    it "distinguishes read and unread" do
      unread = create(:user_notification, :unread, user: user)
      read = create(:user_notification, :read, user: user)

      expect(described_class.unread).to include(unread)
      expect(described_class.unread).not_to include(read)

      expect(described_class.read_scope).to include(read)
      expect(described_class.read_scope).not_to include(unread)

      expect(unread.read?).to be(false)
      expect(read.read?).to be(true)
    end

    it "#mark_as_read! sets read_at timestamp" do
      notification = create(:user_notification, :unread, user: user)
      expect(notification.read_at).to be_nil

      notification.mark_as_read!
      expect(notification.reload.read_at).to be_present
      expect(notification.read?).to be(true)
    end
  end

  describe "real-time notification metrics callbacks" do
    let(:parent_notification) { create(:notification, sent_count: 0, read_count: 0) }

    it "increments sent_count on parent notification upon creation" do
      expect {
        create(:user_notification, user: user, notification: parent_notification)
      }.to change { parent_notification.reload.sent_count }.by(1)
    end

    it "increments read_count on parent notification upon mark_as_read!" do
      user_notif = create(:user_notification, :unread, user: user, notification: parent_notification)
      expect {
        user_notif.mark_as_read!
      }.to change { parent_notification.reload.read_count }.by(1)
    end

    it "does not increment read_count again if already read" do
      user_notif = create(:user_notification, :unread, user: user, notification: parent_notification)
      user_notif.mark_as_read!

      expect {
        user_notif.mark_as_read!
      }.not_to change { parent_notification.reload.read_count }
    end
  end
end
