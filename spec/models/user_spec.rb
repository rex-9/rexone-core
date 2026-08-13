# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    # ===== USERNAME =====
    it { should validate_presence_of(:username) }
    it { should validate_uniqueness_of(:username).case_insensitive }
    it { should validate_length_of(:username).is_at_least(3).is_at_most(30) }

    it { should allow_value('valid_username').for(:username) }
    it { should allow_value('user_123').for(:username) }
    it { should allow_value('a' * 30).for(:username) }
    it { should_not allow_value('InvalidUsername').for(:username) }
    it { should_not allow_value('invalid username!').for(:username) }
    it { should_not allow_value('user@name').for(:username) }
    it { should_not allow_value('a' * 31).for(:username) }
    it { should_not allow_value('ab').for(:username) }

    # ===== EMAIL =====
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }

    it { should allow_value('user@example.com').for(:email) }
    it { should allow_value('user.name@example.co.uk').for(:email) }
    it { should_not allow_value('user').for(:email) }
    it { should_not allow_value('user@').for(:email) }
    it { should_not allow_value('@example.com').for(:email) }
    it { should_not allow_value('user@example.').for(:email) }

    # ===== PASSWORD =====
    it { should validate_presence_of(:password).on(:create) }
    it { should validate_length_of(:password).is_at_least(6) }
    it { should validate_confirmation_of(:password) }

    # ===== NAME =====
    it { should validate_length_of(:name).is_at_most(50) }

    it { should allow_value('').for(:name) }
    it { should allow_value('John Doe').for(:name) }
    it { should allow_value('Jane-Smith').for(:name) }
    it { should allow_value('a' * 50).for(:name) }
    it { should_not allow_value('<script>').for(:name) }
    it { should_not allow_value('test:test').for(:name) }
    it { should_not allow_value('test;test').for(:name) }
    it { should_not allow_value('test?test').for(:name) }
    it { should_not allow_value('a' * 51).for(:name) }
  end

  describe 'associations' do
    it { should have_many(:assets).dependent(:destroy) }
    it { should have_many(:subscriptions).class_name('Payment::Subscription').dependent(:destroy) }
    it { should have_many(:transactions).class_name('Payment::Transaction').dependent(:destroy) }
    it { should have_many(:accesses).dependent(:destroy) }
    it { should have_many(:rooms).class_name('Chat::Room').dependent(:destroy) }
    it { should have_many(:messages).through(:rooms).class_name('Chat::Message') }
    it { should have_many(:user_roles).class_name('Iam::UserRole').dependent(:destroy) }
    it { should have_many(:roles).through(:user_roles).class_name('Iam::Role') }
  end

  describe 'callbacks' do
    describe '#generate_confirmation_code' do
      let(:user) { build(:user) }

      it 'generates a 6-digit confirmation code before creation' do
        expect(user.confirmation_code).to be_nil
        user.save!
        expect(user.confirmation_code).to be_present
        expect(user.confirmation_code).to match(/\A\d{6}\z/)
        expect(user.confirmation_sent_at).to be_present
      end

      it 'generates unique confirmation codes' do
        user1 = create(:user)
        user2 = create(:user)
        expect(user1.confirmation_code).not_to eq(user2.confirmation_code)
      end
    end

    describe '#assign_default_user_role' do
      let(:default_role) { create(:role, name: 'user') }

      before { default_role }

      it 'assigns default "user" role after creation' do
        user = create(:user)
        expect(user.roles).to include(default_role)
      end

      it 'does not override existing roles' do
        admin_role = create(:role, name: 'admin')
        user = create(:user, roles: [ admin_role ])
        expect(user.roles).to include(admin_role)
        expect(user.roles).not_to include(default_role)
      end
    end
  end

  describe 'instance methods' do
    describe '#confirm_code' do
      let(:user) { create(:user) }

      context 'with valid code within time limit' do
        it 'confirms the user' do
          expect(user.confirmed?).to be_falsey
          result = user.confirm_code(user.confirmation_code)
          expect(result).to be_truthy
          expect(user.confirmed?).to be_truthy
        end
      end

      context 'with invalid code' do
        it 'does not confirm the user' do
          expect(user.confirmed?).to be_falsey
          result = user.confirm_code('000000')
          expect(result).to be_falsey
          expect(user.errors[:confirmation_code]).to include('is invalid or has expired')
          expect(user.confirmed?).to be_falsey
        end
      end

      context 'with expired code' do
        it 'does not confirm the user' do
          user.update!(confirmation_sent_at: 2.hours.ago)
          result = user.confirm_code(user.confirmation_code)
          expect(result).to be_falsey
          expect(user.errors[:confirmation_code]).to include('is invalid or has expired')
        end
      end
    end

    describe '#get_profile_pic_url' do
      let(:user) { create(:user) }

      context 'when user has uploaded profile picture' do
        let!(:uploaded_asset) do
          create(:asset,
            user: user,
            category: 'profile',
            source: 'upload',
            url: 'https://example.com/uploaded.jpg'
          )
        end

        let!(:google_asset) do
          create(:asset,
            user: user,
            category: 'profile',
            source: 'google',
            url: 'https://lh3.google.com/photo.jpg'
          )
        end

        it 'returns uploaded picture before google picture' do
          expect(user.get_profile_pic_url).to eq(uploaded_asset.url)
        end
      end

      context 'when user only has google profile picture' do
        let!(:google_asset) do
          create(:asset,
            user: user,
            category: 'profile',
            source: 'google',
            url: 'https://lh3.google.com/photo.jpg'
          )
        end

        it 'returns google picture' do
          expect(user.get_profile_pic_url).to eq(google_asset.url)
        end
      end

      context 'when user has no profile picture' do
        it 'returns nil' do
          expect(user.get_profile_pic_url).to be_nil
        end
      end
    end

    describe '#stripe_customer' do
      let(:user) { create(:user) }

      context 'when stripe_customer_id exists' do
        before { user.update!(stripe_customer_id: 'cus_123') }

        it 'returns existing stripe_customer_id' do
          expect(user.stripe_customer).to eq('cus_123')
        end
      end

      context 'when stripe_customer_id is nil' do
        before do
          allow(Stripe::Customer).to receive(:create).and_return(
            double('customer', id: 'cus_new_123')
          )
        end

        it 'creates a new Stripe customer' do
          expect(user.stripe_customer).to eq('cus_new_123')
          expect(user.reload.stripe_customer_id).to eq('cus_new_123')
        end
      end

      context 'when Stripe API fails' do
        before do
          allow(Stripe::Customer).to receive(:create).and_raise(
            Stripe::StripeError.new('API error')
          )
        end

        it 'logs error and returns nil' do
          expect(Rails.logger).to receive(:error).with(/Failed to create customer/)
          expect(user.stripe_customer).to be_nil
        end
      end
    end

    describe '#has_role?' do
      let(:user) { create(:user) }

      before do
        role = create(:role, name: 'admin')
        create(:user_role, user: user, role: role)
      end

      it 'returns true when user has the role' do
        expect(user.has_role?('admin')).to be_truthy
      end

      it 'returns false when user does not have the role' do
        expect(user.has_role?('super_admin')).to be_falsey
      end

      it 'accepts symbols' do
        expect(user.has_role?(:admin)).to be_truthy
      end
    end

    describe '#has_permission?' do
      let(:user) { create(:user) }
      let(:role) { create(:role, name: 'editor') }
      let(:permission) { create(:permission, action: 'read', resource: 'posts') }

      before do
        create(:user_role, user: user, role: role)
        create(:role_permission, role: role, permission: permission)
      end

      it 'returns true when user has the permission' do
        expect(user.has_permission?('read', 'posts')).to be_truthy
      end

      it 'returns false when user does not have the permission' do
        expect(user.has_permission?('write', 'posts')).to be_falsey
      end

      it 'accepts symbols' do
        expect(user.has_permission?(:read, :posts)).to be_truthy
      end
    end

    describe '#can?' do
      let(:user) { create(:user) }

      context 'when user is super_admin' do
        before do
          role = create(:role, name: 'super_admin')
          create(:user_role, user: user, role: role)
        end

        it 'returns true for any action/resource' do
          expect(user.can?('destroy', 'system')).to be_truthy
          expect(user.can?('anything', 'everything')).to be_truthy
        end
      end

      context 'when user is not super_admin' do
        let(:permission) { create(:permission, action: 'read', resource: 'posts') }

        before do
          role = create(:role, name: 'viewer')
          create(:user_role, user: user, role: role)
          create(:role_permission, role: role, permission: permission)
        end

        it 'returns true when user has the permission' do
          expect(user.can?('read', 'posts')).to be_truthy
        end

        it 'returns false when user does not have the permission' do
          expect(user.can?('write', 'posts')).to be_falsey
        end
      end
    end

    describe '#admin?' do
      let(:user) { create(:user) }

      context 'when user has super_admin role' do
        before do
          create(:user_role, user: user, role: create(:role, name: 'super_admin'))
        end

        it 'returns true' do
          expect(user.admin?).to be_truthy
        end
      end

      context 'when user has admin role' do
        before do
          create(:user_role, user: user, role: create(:role, name: 'admin'))
        end

        it 'returns true' do
          expect(user.admin?).to be_truthy
        end
      end

      context 'when user has neither role' do
        it 'returns false' do
          expect(user.admin?).to be_falsey
        end
      end
    end

    describe '#super_admin?' do
      let(:user) { create(:user) }

      context 'when user has super_admin role' do
        before do
          create(:user_role, user: user, role: create(:role, name: 'super_admin'))
        end

        it 'returns true' do
          expect(user.super_admin?).to be_truthy
        end
      end

      context 'when user has admin role' do
        before do
          create(:user_role, user: user, role: create(:role, name: 'admin'))
        end

        it 'returns false' do
          expect(user.super_admin?).to be_falsey
        end
      end

      context 'when user has no role' do
        it 'returns false' do
          expect(user.super_admin?).to be_falsey
        end
      end
    end

    describe '#permissions' do
      let(:user) { create(:user) }
      let(:role1) { create(:role, name: 'editor') }
      let(:role2) { create(:role, name: 'viewer') }
      let(:perm1) { create(:permission, action: 'read', resource: 'posts') }
      let(:perm2) { create(:permission, action: 'write', resource: 'posts') }
      let(:perm3) { create(:permission, action: 'read', resource: 'comments') }

      before do
        create(:user_role, user: user, role: role1)
        create(:user_role, user: user, role: role2)
        create(:role_permission, role: role1, permission: perm1)
        create(:role_permission, role: role1, permission: perm2)
        create(:role_permission, role: role2, permission: perm3)
      end

      it 'returns all distinct permissions from all roles' do
        perms = user.permissions
        expect(perms).to include(perm1, perm2, perm3)
        expect(perms.count).to eq(3)
      end

      it 'returns distinct permissions' do
        # Add duplicate permission to role2
        create(:role_permission, role: role2, permission: perm1)
        perms = user.permissions
        expect(perms.count).to eq(3) # Still only 3 distinct permissions
      end
    end

    describe '#role_names' do
      let(:user) { create(:user) }

      before do
        create(:user_role, user: user, role: create(:role, name: 'admin'))
        create(:user_role, user: user, role: create(:role, name: 'editor'))
      end

      it 'returns array of role names' do
        expect(user.role_names).to match_array(%w[admin editor])
      end
    end
  end

  describe 'Devise modules' do
    it 'includes Devise::JWT::RevocationStrategies::JTIMatcher' do
      expect(User.ancestors).to include(Devise::JWT::RevocationStrategies::JTIMatcher)
    end

    it { is_expected.to respond_to(:jwt_revoked?) }
    it { is_expected.to respond_to(:revoke_jwt) }
  end
end
