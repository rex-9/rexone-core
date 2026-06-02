require 'rails_helper'

RSpec.describe Users::ConfirmationsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, username: 'testusername', email: 'test@example.com', password: 'password', confirmed_at: nil) }
  let(:confirmed_user) { create(:user, username: 'confirmeduser', email: 'confirmed@example.com', password: 'password', confirmed_at: Time.now) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'GET #show' do
    context 'with valid confirmation token' do
      it 'confirms the user and redirects to the client with auth token' do
        get :show, params: { confirmation_token: user.confirmation_token }
        expect(response).to redirect_to("#{AppConfig::CLIENT_BASE_URL}/signin?auth_token=#{user.reload.jti}")
      end
    end

    context 'with invalid confirmation token' do
      it 'redirects to the client with error message' do
        get :show, params: { confirmation_token: 'invalid_token' }
        expect(response).to redirect_to("#{AppConfig::CLIENT_BASE_URL}/signin?error=Confirmation token is invalid")
      end
    end
  end

  describe 'POST #send' do
    context 'with valid signin key and unconfirmed user' do
      it 'with email, sends confirmation instructions and returns a success response' do
        post :send, params: { signin_key: user.email }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::VERIFICATION_EMAIL_SENT.call(user.email))
      end

      it 'with username, sends confirmation instructions and returns a success response' do
        post :send, params: { signin_key: user.username }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::VERIFICATION_EMAIL_SENT.call(user.email))
      end

      it 'returns an error if the user is already confirmed' do
        post :send, params: { signin_key: confirmed_user.email }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['message']).to eq(Messages::EMAIL_ALREADY_CONFIRMED)
      end
    end


    context 'with invalid signin key' do
      it 'returns a not found response' do
        post :send, params: { signin_key: 'nonexistent@example.com' }
        expect(response).to have_http_status(:not_found)
        expect(json_response['status']['code']).to eq(404)
        expect(json_response['status']['message']).to eq(Messages::USER_NOT_FOUND)
      end
    end
  end

  describe 'POST #confirm_code' do
    context 'with valid confirmation code' do
      it 'confirms the user and returns a success response' do
        user.generate_confirmation_code
        user.save
        post :confirm_code, params: { signin_key: user.email, confirmation_code: user.confirmation_code }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::EMAIL_CONFIRMED_SUCCESSFULLY)
        expect(json_response['data']['user']['email']).to eq(user.email)
        expect(json_response['data']['token']).to eq(AppConfig::JWT_TOKEN.call(user))
      end
    end

    context 'with invalid confirmation code' do
      it 'returns an unprocessable entity response' do
        post :confirm_code, params: { signin_key: user.email, confirmation_code: 'invalid_code' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['message']).to eq(Messages::EMAIL_FAILED_TO_CONFIRM)
      end
    end

    context 'with expired confirmation code' do
      it 'returns an unprocessable entity response' do
        user.generate_confirmation_code
        user.confirmation_code_sent_at = 11.minutes.ago
        user.save
        post :confirm_code, params: { signin_key: user.email, confirmation_code: user.confirmation_code }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['message']).to eq(Messages::EMAIL_FAILED_TO_CONFIRM)
      end
    end

    context 'with invalid signin key' do
      it 'returns an unprocessable entity response' do
        post :confirm_code, params: { signin_key: 'nonexistent@example.com', confirmation_code: '123456' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['message']).to eq(Messages::EMAIL_FAILED_TO_CONFIRM)
      end
    end
  end
end
