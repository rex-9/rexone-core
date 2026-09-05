require "rails_helper"

RSpec.describe Notification::CleanupJob, type: :job do
  let(:user) { create(:user) }

  it "purges old read, unread, and discarded notifications based on retention rules" do
    # 1. Read notification older than 30 days -> purged
    old_read = create(:user_notification, user: user, read_at: 31.days.ago, created_at: 35.days.ago)
    # 2. Read notification newer than 30 days -> kept
    recent_read = create(:user_notification, user: user, read_at: 10.days.ago, created_at: 15.days.ago)

    # 3. Unread notification older than 90 days -> purged
    old_unread = create(:user_notification, :unread, user: user, created_at: 95.days.ago)
    # 4. Unread notification newer than 90 days -> kept
    recent_unread = create(:user_notification, :unread, user: user, created_at: 20.days.ago)

    # 5. Discarded notification older than 7 days -> purged
    old_discarded = create(:user_notification, user: user, discarded_at: 8.days.ago, created_at: 20.days.ago)
    # 6. Discarded notification newer than 7 days -> kept
    recent_discarded = create(:user_notification, user: user, discarded_at: 2.days.ago, created_at: 10.days.ago)

    described_class.perform_now

    expect(UserNotification.unscoped.exists?(old_read.id)).to be(false)
    expect(UserNotification.unscoped.exists?(recent_read.id)).to be(true)

    expect(UserNotification.unscoped.exists?(old_unread.id)).to be(false)
    expect(UserNotification.unscoped.exists?(recent_unread.id)).to be(true)

    expect(UserNotification.unscoped.exists?(old_discarded.id)).to be(false)
    expect(UserNotification.unscoped.exists?(recent_discarded.id)).to be(true)
  end
end
