require 'rails_helper'

RSpec.describe Users::PasswordsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:google_user) { create(:user, email: 'google.reset@example.com', provider: 'google', password: 'password', password_confirmation: 'password', confirmed_at: Time.current) }
  let(:unconfirmed_user) { create(:user, confirmed_at: nil) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'POST #create' do
    context 'with valid email' do
      it 'sends reset passcode instructions and returns a success response' do
        post :create, params: { email: user.email }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::PASSWORD_RESET_INSTRUCTIONS_SENT.call(user.email))
      end
    end

    context 'with Google user email' do
      it 'also sends reset passcode instructions' do
        post :create, params: { email: google_user.email }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::PASSWORD_RESET_INSTRUCTIONS_SENT.call(google_user.email))
      end
    end

    context 'with invalid email' do
      it 'returns a not found response' do
        post :create, params: { email: 'nonexistent@example.com' }
        expect(response).to have_http_status(:not_found)
        expect(json_response['status']['code']).to eq(404)
        expect(json_response['status']['message']).to eq(Messages::EMAIL_NOT_FOUND)
      end
    end
  end

  describe 'PUT #update' do
    let(:reset_password_token) { user.send_reset_password_instructions }

    context 'with valid reset passcode token' do
      it 'resets the passcode and returns a success response' do
        put :update, params: { user: { reset_password_token: reset_password_token, password: 'newpassword', password_confirmation: 'newpassword' } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::PASSWORD_RESET_SUCCESSFULLY)
      end
    end

    context 'with invalid reset passcode token' do
      it 'returns an unprocessable entity response' do
        put :update, params: { user: { reset_password_token: 'invalid_token', password: 'newpassword', password_confirmation: 'newpassword' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_RESET_PASSWORD)
      end
    end
  end

  describe 'GET #edit' do
    let(:reset_password_token) { user.send_reset_password_instructions }

    it 'redirects to the client with reset passcode token' do
      get :edit, params: { reset_password_token: reset_password_token }
      expect(response).to redirect_to("#{AppConfig::CLIENT_BASE_URL}/password/reset?reset_password_token=#{reset_password_token}")
    end
  end
end
