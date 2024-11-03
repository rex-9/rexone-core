require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    # username
    it { should validate_presence_of(:username) }
    it 'validates uniqueness of username case insensitively' do
      create(:user, username: 'testusername')
      should validate_uniqueness_of(:username).case_insensitive
    end
    it { should validate_length_of(:username).is_at_least(3).is_at_most(30) }
    it { should allow_value('valid_username').for(:username) }
    it { should_not allow_value('invalid username!').for(:username) }

    context 'when username includes special characters' do
      let(:user) { build(:user, username: 'invalid username!') }

      it 'should not allow special characters in username' do
        expect(user).not_to be_valid
      end
    end

    context 'when username is valid' do
      let(:user) { build(:user, username: 'valid_username') }

      it 'should allow valid username' do
        expect(user).to be_valid
      end
    end

    # email
    it { should validate_presence_of(:email) }

    it 'validates uniqueness of email case insensitively' do
      create(:user, email: 'test@example.com')
      should validate_uniqueness_of(:email).case_insensitive
    end
    it { should allow_value('user@example.com').for(:email) }
    it { should_not allow_value('user').for(:email) }

    context 'when email is not the email format' do
      let(:user) { build(:user, email: 'user') }
      it 'email should be the correct email format' do
        expect(user).not_to be_valid
      end
    end

    # password
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }

    # name
    it { should validate_length_of(:name).is_at_most(50) }

    context 'when name is blank' do
      let(:user) { build(:user, name: '') }
      it 'should allow the blank' do
        expect(user).to be_valid
      end
    end

    context 'when name includes special characters' do
      let(:user) { build(:user, name: '<:;?') }

      it 'should not allow the special characters in name' do
        expect(user).not_to be_valid
      end
    end

    # photo
    context 'when photo is not valid url' do
      let(:user) { build(:user, photo: 'testing.com') }
      it 'photo should not be invalid url' do
        expect(user).not_to be_valid
      end
    end

    context 'when photo is a valid url' do
      let(:user) { build(:user, photo: 'https://www.google.com/') }
      it 'photo should be valid url' do
        expect(user).to be_valid
      end
    end
  end
end
