# spec/controllers/users/sessions_controller_spec.rb
require 'rails_helper'

RSpec.describe Users::SessionsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, password: 'password123', confirmed_at: Time.current) }
  let(:unconfirmed_user) { create(:user, :unconfirmed, password: 'password123') }
  let(:google_user) { create(:user, :google_provider) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'POST #create' do
    context 'with valid credentials' do
      it 'signs in user and returns token' do
        post :create, params: { user: { signin_key: user.email, password: 'password123' } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
        expect(json_response['data']['token']).to be_present
        expect(json_response['data']['remaining_attempts']).to eq(3)
      end

      it 'works with username' do
        post :create, params: { user: { signin_key: user.username, password: 'password123' } }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user']['username']).to eq(user.username)
      end
    end

    context 'with unconfirmed user' do
      it 'sends confirmation code and returns otp_sent' do
        expect {
          post :create, params: { user: { signin_key: unconfirmed_user.email, password: 'password123' } }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['otp_sent']).to be true
        expect(json_response['status']['message']).to eq(Messages::VERIFICATION_EMAIL_SENT.call(unconfirmed_user.email))
      end
    end

    context 'with invalid password' do
      it 'returns 401 with attempt tracking' do
        post :create, params: { user: { signin_key: user.email, password: 'wrongpassword' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::INVALID_SIGNIN_CREDENTIALS)
        expect(json_response['data']['remaining_attempts']).to be_present
      end
    end

    context 'with 3 failed attempts' do
      before do
        3.times do
          post :create, params: { user: { signin_key: user.email, password: 'wrongpassword' } }
        end
      end

      it 'triggers cooldown on 4th attempt' do
        post :create, params: { user: { signin_key: user.email, password: 'wrongpassword' } }
        expect(response).to have_http_status(:too_many_requests)
        expect(json_response['status']['code']).to eq(429)
        expect(json_response['data']['cooldown_remaining']).to be > 0
        expect(json_response['data']['remaining_attempts']).to eq(0)
      end
    end

    context 'with non-existent user' do
      it 'returns 401' do
        post :create, params: { user: { signin_key: 'nonexistent@example.com', password: 'password123' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::USER_NOT_FOUND)
      end
    end

    context 'with Google provider user' do
      let(:google_user) { create(:user, :google_provider) }

      it 'returns error' do
        post :create, params: { user: { signin_key: google_user.email, password: 'password123' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to include('Google')
      end
    end
  end

  describe 'POST #token_sign_in' do
    let(:user) { create(:user) }

    context 'with valid token' do
      it 'signs in user' do
        post :token_sign_in, params: { token: user.jti }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
        expect(json_response['data']['token']).to be_present
      end
    end

    context 'with invalid token' do
      it 'returns 401' do
        post :token_sign_in, params: { token: 'invalid_token' }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::INVALID_AUTHENTICATION_TOKEN)
      end
    end
  end

  describe 'POST #google_sign_in' do
    let(:valid_google_token) { 'valid_google_token' }
    let(:google_user_info) do
      {
        "email" => "google@example.com",
        "name" => "Google User",
        "picture" => "https://example.com/photo.jpg"
      }
    end

    before do
      allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info)
    end

    context 'with existing Google user' do
      let!(:existing_google_user) { create(:user, :google_provider, email: google_user_info["email"]) }

      it 'signs in user' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(existing_google_user.email)
        expect(json_response['data']['token']).to be_present
      end
    end

    context 'with existing email user' do
      let!(:existing_email_user) { create(:user, email: google_user_info["email"]) }

      it 'signs in user' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user']['email']).to eq(existing_email_user.email)
        expect(json_response['data']['token']).to be_present
      end
    end

    context 'with new user' do
      it 'returns challenge token' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['password_required']).to be true
        expect(json_response['data']['challenge_token']).to be_present
      end
    end

    context 'with invalid Google token' do
      before do
        allow(controller).to receive(:get_google_user_info).and_return(nil)
      end

      it 'returns 401' do
        post :google_sign_in, params: { token: 'invalid_token' }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::GOOGLE_AUTHENTICATION_FAILED)
      end
    end
  end

  describe 'POST #google_sign_in_complete' do
    let(:challenge_token) { 'valid_challenge_token' }
    let(:challenge_data) do
      {
        "email" => "new_google@example.com",
        "name" => "New Google User",
        "picture" => "https://example.com/photo.jpg"
      }
    end

    before do
      allow(controller).to receive(:fetch_google_challenge).with(challenge_token).and_return(challenge_data)
      allow(controller).to receive(:clear_google_challenge!)
    end

    context 'with valid challenge token and passcode' do
      it 'creates new user and signs in' do
        expect {
          post :google_sign_in_complete, params: {
            challenge_token: challenge_token,
            password: 'password123'
          }
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['status']['code']).to eq(201)
        expect(json_response['data']['user']['email']).to eq(challenge_data["email"])
        expect(json_response['data']['token']).to be_present
      end
    end

    context 'with missing challenge token' do
      it 'returns 422' do
        post :google_sign_in_complete, params: { password: 'password123' }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('Challenge token')
      end
    end

    context 'with missing passcode' do
      it 'returns 422' do
        post :google_sign_in_complete, params: { challenge_token: challenge_token }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('passcode')
      end
    end

    context 'with expired challenge token' do
      before do
        allow(controller).to receive(:fetch_google_challenge).with(challenge_token).and_return(nil)
      end

      it 'returns 401' do
        post :google_sign_in_complete, params: {
          challenge_token: challenge_token,
          password: 'password123'
        }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::INVALID_AUTHENTICATION_TOKEN)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when signed in' do
      before do
        sign_in user
        allow(controller).to receive(:clear_active_session!).and_return(true)
      end

      it 'signs out successfully' do
        delete :destroy
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::SIGNED_OUT_SUCCESSFULLY)
      end
    end

    context 'when not signed in' do
      it 'returns 401' do
        delete :destroy
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::ACTIVE_SESSION_NOT_FOUND)
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end