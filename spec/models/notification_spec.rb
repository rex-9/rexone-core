require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      notification = build(:notification)
      expect(notification).to be_valid
    end

    it "requires event, name, and category" do
      expect(build(:notification, event: nil)).not_to be_valid
      expect(build(:notification, name: nil)).not_to be_valid
      expect(build(:notification, category: nil)).not_to be_valid
    end

    it "validates inclusion of category in allowed values" do
      expect(build(:notification, category: "invalid_category")).not_to be_valid
      expect(build(:notification, category: NotificationConstants::Category::MARKETING)).to be_valid
      expect(build(:notification, category: NotificationConstants::Category::SYSTEM)).to be_valid
      expect(build(:notification, category: NotificationConstants::Category::BROADCAST)).to be_valid
    end

    it "enforces uniqueness of event among kept notifications" do
      create(:notification, event: "unique_event")
      expect(build(:notification, event: "unique_event")).not_to be_valid
    end
  end

  describe "#render_text" do
    let(:notification) { build(:notification) }
    let(:user) { build(:user, name: "Rex", email: "rex@example.com") }

    it "replaces {{user_name}} and {{user_email}} placeholders" do
      rendered = notification.render_text("Hello {{user_name}}, sent to {{user_email}}!", user: user)
      expect(rendered).to eq("Hello Rex, sent to rex@example.com!")
    end

    it "interpolates custom context variables" do
      rendered = notification.render_text("Amount: {{amount}} {{currency}}", user: user, context: { amount: "100", currency: "USD" })
      expect(rendered).to eq("Amount: 100 USD")
    end

    it "handles nil text safely" do
      expect(notification.render_text(nil, user: user)).to eq("")
    end
  end
end
