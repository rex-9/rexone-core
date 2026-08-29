require "rails_helper"

RSpec.describe User, type: :model do
  describe "authentication validations" do
    it "accepts a complete email account" do
      expect(build(:user)).to be_valid
    end

    it "requires a safe name no longer than 50 characters" do
      expect(build(:user, name: nil)).not_to be_valid
      expect(build(:user, name: "Bad<Name")).not_to be_valid
      expect(build(:user, name: "A" * 51)).not_to be_valid
    end

    it "requires a valid, case-insensitively unique email" do
      create(:user, email: "person@example.com")

      expect(build(:user, email: "invalid")).not_to be_valid
      expect(build(:user, email: "PERSON@example.com")).not_to be_valid
    end

    it "accepts only lowercase usernames made of letters, digits, and underscores" do
      %w[ab Uppercase user-name user.name].each do |username|
        expect(build(:user, username: username)).not_to be_valid
      end
      expect(build(:user, username: "valid_user9")).to be_valid
    end

    it "enforces case-insensitive username uniqueness" do
      create(:user, username: "unique_user")
      expect(build(:user, username: "UNIQUE_USER")).not_to be_valid
    end

    it "requires a matching password of at least six characters" do
      expect(build(:user, password: "short", password_confirmation: "short")).not_to be_valid
      expect(build(:user, password_confirmation: "different")).not_to be_valid
    end

    it "allows profile updates without resubmitting the password" do
      expect(create(:user).update(name: "Changed Name")).to be(true)
    end
  end

  describe "confirmation codes" do
    it "generates a six-digit code and timestamp before creation" do
      user = create(:user)
      expect(user.confirmation_code).to match(/\A\d{6}\z/)
      expect(user.confirmation_sent_at).to be_present
    end

    it "confirms an unexpired matching code" do
      user = create(:user, :unconfirmed)
      user.update_columns(confirmation_code: "123456", confirmation_sent_at: 1.minute.ago)

      expect(user.confirm_code("123456")).to be(true)
      expect(user.reload).to be_confirmed
    end

    it "rejects wrong, missing-timestamp, and expired codes" do
      user = create(:user, :unconfirmed)
      expect(user.confirm_code("wrong")).to be(false)

      user.errors.clear
      user.update_columns(confirmation_code: "123456", confirmation_sent_at: nil)
      expect(user.confirm_code("123456")).to be(false)

      user.errors.clear
      user.update_columns(confirmation_sent_at: AppConfig::CONFIRM_CODE_WITHIN.ago - 1.second)
      expect(user.confirm_code("123456")).to be(false)
    end
  end

  describe "role assignment" do
    it "assigns the default role when it exists" do
      role = create(:role, name: "user")
      expect(create(:user).roles).to contain_exactly(role)
    end

    it "creates normally if the default role has not been seeded" do
      expect { create(:user) }.to change(described_class, :count).by(1)
    end
  end

  describe "RBAC and permission scoping" do
    let(:user_role) { create(:role, name: "user") }
    let(:feedback_admin_role) { create(:role, name: "feedback_admin") }
    let(:user_admin_role) { create(:role, name: "user_admin") }
    let(:read_users_perm) { create(:permission, action: "read", resource: "users") }
    let(:read_feedbacks_perm) { create(:permission, action: "read", resource: "feedbacks") }

    before do
      user_role.permissions << read_users_perm
      feedback_admin_role.permissions << read_feedbacks_perm
      user_admin_role.permissions << read_users_perm
    end

    it "identifies admin roles by name containing admin" do
      user = create(:user)
      expect(user.admin?).to be(false)

      user.roles << feedback_admin_role
      expect(user.admin?).to be(true)
      expect(user.admin_roles).to contain_exactly(feedback_admin_role)
    end

    it "allows non-admin permissions for non-admin scope but restricts admin scope to admin roles" do
      user = create(:user)
      user.roles << feedback_admin_role

      # Non-admin scope: permissions from both user and feedback_admin roles work
      expect(user.can?(:read, "users", admin_scope: false)).to be(true)
      expect(user.can?(:read, "feedbacks", admin_scope: false)).to be(true)

      # Admin scope: only permissions granted by admin roles work
      expect(user.can?(:read, "feedbacks", admin_scope: true)).to be(true)
      expect(user.can?(:read, "users", admin_scope: true)).to be(false) # read_users is only in 'user' role
    end

    it "allows admin scope when permission is in a dedicated admin role" do
      user = create(:user)
      user.roles << user_admin_role

      expect(user.can?(:read, "users", admin_scope: true)).to be(true)
    end
  end

  describe "JWT revocation" do
    it "replaces its JTI and rejects the old token identifier" do
      user = create(:user)
      old_jti = user.jti
      described_class.revoke_jwt({ "jti" => old_jti }, user)

      expect(user.reload.jti).not_to eq(old_jti)
      expect(described_class.jwt_revoked?({ "jti" => old_jti }, user)).to be(true)
      expect(described_class.jwt_revoked?({ "jti" => user.jti }, user)).to be(false)
    end
  end
end
