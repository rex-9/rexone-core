require 'rails_helper'

RSpec.describe Users::SessionsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, username: 'testusername', email: 'test@example.com', password: 'password', confirmed_at: Time.now) }
  let(:google_user) { create(:user, email: 'google@example.com', provider: 'google', password: 'password', password_confirmation: 'password', confirmed_at: Time.now) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'POST #create' do
    context 'with valid email and password' do
      it 'returns a success response' do
        post :create, params: { user: { signin_key: user.email, password: user.password } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
      end
    end

    context 'with valid username and password' do
      it 'signs in the user and returns a success response' do
        post :create, params: { user: { signin_key: user.username, password: user.password } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['username']).to eq(user.username)
      end
    end

    context 'with invalid signin credentials' do
      it 'returns an unauthorized response' do
        post :create, params: { user: { signin_key: 'wrongsignin', password: 'wrongpassword' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_SIGN_IN)
        expect(json_response['status']['error']).to eq(Messages::USER_NOT_FOUND)
      end
    end

    context 'with invalid password' do
      it 'returns an unauthorized response' do
        post :create, params: { user: { signin_key: user.email, password: 'wrong_password' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_SIGN_IN)
        expect(json_response['status']['error']).to eq(Messages::INVALID_SIGNIN_CREDENTIALS)
      end
    end

    context 'with unconfirmed user' do
      let(:unconfirmed_user) { create(:user, username: 'unconfirmeduser', email: 'unconfirmed@example.com', password: 'password') }

      it 'sends confirmation instructions and returns a success response' do
        post :create, params: { user: { signin_key: unconfirmed_user.email, password: unconfirmed_user.password } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::VERIFICATION_EMAIL_SENT.call(unconfirmed_user.email))
      end
    end

    context 'with Google signed up email and correct passcode' do
      it 'returns a success response' do
        post :create, params: { user: { signin_key: google_user.email, password: 'password' } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(google_user.email)
      end
    end
  end

  describe 'POST #token_sign_in' do
    context 'with valid token' do
      it 'signs in the user and returns a success response' do
        post :token_sign_in, params: { token: user.jti }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
      end
    end

    context 'with invalid token' do
      it 'returns an unauthorized response' do
        post :token_sign_in, params: { token: 'invalid_token' }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::INVALID_AUTHENTICATION_TOKEN)
      end
    end
  end

  describe 'POST #google_sign_in' do
    let(:valid_google_token) { 'valid_google_token' }
    let(:invalid_google_token) { 'invalid_google_token' }
    let(:google_user_info) do
      {
      "email" => "google@example.com",
      "name" => "Google User",
      "picture" => "https://res.cloudinary.com/meritbox/image/upload/v1733153191/cld-sample-4.jpg"
      }
    end

    before do
      allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info)
      allow(controller).to receive(:get_google_user_info).with(invalid_google_token).and_return(nil)
    end

    context 'with valid Google token and existing SSO user' do
      let!(:google_user) { create(:user, email: google_user_info['email'], provider: 'google', password: 'password', password_confirmation: 'password', confirmed_at: Time.now) }
      it 'signs in the user and returns a success response' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(google_user.email)
        expect(json_response['data']['passcode_required']).to eq(false)
        expect(json_response['data']['existing_user']).to eq(true)
      end
    end

    context 'with valid Google token and existing email user' do
      let!(:email_user) { create(:user, email: google_user_info['email'], provider: 'email', password: 'password', password_confirmation: 'password', confirmed_at: Time.now) }

      it 'signs in without asking passcode in Google step' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(email_user.email)
        expect(json_response['data']['passcode_required']).to eq(false)
      end
    end

    context 'with valid Google token and new user' do
      it 'returns a passcode challenge' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['passcode_required']).to eq(true)
        expect(json_response['data']['challenge_token']).to be_present
      end
    end

    context 'with invalid Google token' do
      it 'returns an unauthorized response' do
        post :google_sign_in, params: { token: invalid_google_token }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq(Messages::GOOGLE_AUTHENTICATION_FAILED)
      end
    end

    context 'with various email formats' do
      it 'returns a challenge for each valid email format' do
        emails = [
          'john.doe@example.com',
          'Jane-Doe123@example.com',
          'user+alias@example.com',
          'user.name@domain.com',
          'user@domain.com'
        ]

        emails.each_with_index do |email, index|
          pic = "https://res.cloudinary.com/meritbox/image/upload/v1733153191/cld-sample-#{index}.jpg"
          allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info.merge("email" => email, "picture" => pic))
          post :google_sign_in, params: { token: valid_google_token }
          expect(response).to have_http_status(:ok)
          expect(json_response['data']['challenge_token']).to be_present
          expect(json_response['data']['passcode_required']).to eq(true)
        end
      end
    end
  end

  describe 'POST #google_sign_in_complete' do
    let(:valid_google_token) { 'valid_google_token' }
    let(:google_user_info) do
      {
        "email" => "new_google_user@example.com",
        "name" => "Google User",
        "picture" => "https://res.cloudinary.com/meritbox/image/upload/v1733153191/cld-sample-4.jpg"
      }
    end

    before do
      allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info)
    end

    it 'creates a new Google user with passcode and signs in' do
      post :google_sign_in, params: { token: valid_google_token }
      challenge_token = json_response.dig('data', 'challenge_token')

      post :google_sign_in_complete, params: {
        challenge_token: challenge_token,
        passcode: 'password123'
      }

      expect(response).to have_http_status(:created)
      expect(json_response['status']['code']).to eq(201)
      expect(json_response['data']['user']['email']).to eq(google_user_info['email'])
    end

    it 'returns 422 when challenge token is missing' do
      post :google_sign_in_complete, params: { passcode: 'password123' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['status']['code']).to eq(422)
    end
  end
end
