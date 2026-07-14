# spec/controllers/users/registrations_controller_spec.rb
require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        user: {
          username: 'newuser',
          name: 'New User',
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    context 'with valid params' do
      it 'creates a new user' do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['status']['code']).to eq(201)
        expect(json_response['data']['user']['email']).to eq('newuser@example.com')
        expect(json_response['data']['user']['username']).to eq('newuser')
      end

      it 'sends confirmation email' do
        expect {
          post :create, params: valid_params
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sets provider to email' do
        post :create, params: valid_params
        expect(User.last.provider).to eq('email')
      end
    end

    context 'with duplicate email' do
      let!(:existing_user) { create(:user, email: 'newuser@example.com') }

      it 'returns error' do
        post :create, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to be_present
      end
    end

    context 'with duplicate username' do
      let!(:existing_user) { create(:user, username: 'newuser') }

      it 'returns error' do
        post :create, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to be_present
      end
    end

    context 'with mismatched passwords' do
      let(:invalid_params) do
        {
          user: {
            username: 'newuser',
            name: 'New User',
            email: 'newuser@example.com',
            password: 'password123',
            password_confirmation: 'differentpassword'
          }
        }
      end

      it 'returns error' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('confirmation')
      end
    end

    context 'with email already signed up with Google' do
      let!(:google_user) { create(:user, :google_provider, email: 'newuser@example.com') }

      it 'returns error' do
        post :create, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('Google')
      end
    end

    context 'with invalid username format' do
      let(:invalid_username_params) do
        {
          user: {
            username: 'invalid username!',
            name: 'New User',
            email: 'newuser@example.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      end

      it 'returns error' do
        post :create, params: invalid_username_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('Username')
        expect(json_response['status']['error']).to match(/username/i)
      end
    end

    context 'with too short username' do
      let(:short_username_params) do
        {
          user: {
            username: 'ab',
            name: 'New User',
            email: 'newuser@example.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      end

      it 'returns error' do
        post :create, params: short_username_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('Username')
        expect(json_response['status']['error']).to match(/username/i)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it 'deletes the user' do
      expect {
        delete :destroy
      }.to change(User, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['status']['code']).to eq(200)
      expect(json_response['status']['message']).to eq(Messages::ACCOUNT_DELETED_SUCCESSFULLY)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end