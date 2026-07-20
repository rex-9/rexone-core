# spec/controllers/users/confirmations_controller_spec.rb
require 'rails_helper'

RSpec.describe Users::ConfirmationsController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'GET #show' do
    context 'with valid confirmation token' do
      let(:user) { create(:user, :unconfirmed) }
      let(:token) { user.confirmation_token }

      it 'confirms the user and redirects with auth_token' do
        get :show, params: { confirmation_token: token }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(/#{AppConfig::CLIENT_BASE_URL}\/email\/confirm\?auth_token=/)
        expect(user.reload.confirmed?).to be true
      end
    end

    context 'with invalid confirmation token' do
      it 'redirects with error message' do
        get :show, params: { confirmation_token: 'invalid_token' }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(/#{AppConfig::CLIENT_BASE_URL}\/email\/confirm\?error=/)
      end
    end

    context 'with expired confirmation token' do
      let(:user) { create(:user, :unconfirmed, confirmation_sent_at: 3.days.ago) }
      let(:token) { user.confirmation_token }

      it 'redirects with error message' do
        get :show, params: { confirmation_token: token }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(/#{AppConfig::CLIENT_BASE_URL}\/email\/confirm\?error=/)
        expect(user.reload.confirmed?).to be false
      end
    end
  end

  describe 'POST #send_code' do
    let(:user) { create(:user, :unconfirmed) }

    context 'with valid email' do
      it 'sends confirmation code and returns success' do
        expect {
          post :send_code, params: { signin_key: user.email }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::CONFIRMATION_EMAIL_SENT.call(user.email))
      end
    end

    context 'with valid username' do
      it 'sends confirmation code to associated email' do
        post :send_code, params: { signin_key: user.username }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
      end
    end

    context 'with already confirmed user' do
      let(:confirmed_user) { create(:user) }

      it 'returns error' do
        post :send_code, params: { signin_key: confirmed_user.email }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to eq(Messages::EMAIL_ALREADY_CONFIRMED)
      end
    end

    context 'with non-existent user' do
      it 'returns 404' do
        post :send_code, params: { signin_key: 'nonexistent@example.com' }
        expect(response).to have_http_status(:not_found)
        expect(json_response['status']['code']).to eq(404)
        expect(json_response['status']['error']).to eq(Messages::USER_NOT_FOUND)
      end
    end
  end

  describe 'POST #confirm_code' do
    let(:user) { create(:user, :unconfirmed) }

    context 'with valid confirmation code' do
      it 'confirms user and returns token' do
        post :confirm_code, params: {
          signin_key: user.email,
          confirmation_token: user.confirmation_token
        }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
        expect(json_response['data']['token']).to be_present
        expect(user.reload.confirmed?).to be true
      end
    end

    context 'with expired confirmation code' do
      before do
        user.update(confirmation_sent_at: 15.minutes.ago)
      end

      it 'returns error' do
        post :confirm_code, params: {
          signin_key: user.email,
          confirmation_token: user.confirmation_token
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('expired')
        expect(user.reload.confirmed?).to be false
      end
    end

    context 'with invalid confirmation code' do
      it 'returns error' do
        post :confirm_code, params: {
          signin_key: user.email,
          confirmation_token: '123456'
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('invalid')
      end
    end

    context 'with non-existent user' do
      it 'returns 422' do
        post :confirm_code, params: {
          signin_key: 'nonexistent@example.com',
          confirmation_token: '123456'
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to eq(Messages::USER_NOT_FOUND)
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
