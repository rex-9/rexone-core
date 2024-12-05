require 'rails_helper'

RSpec.describe Users::SessionsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, username: 'testusername', email: 'test@example.com', password: 'password', confirmed_at: Time.now) }
  let(:google_user) { create(:user, email: 'google@example.com', provider: 'google', confirmed_at: Time.now) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'POST #create' do
    context 'with valid email and password' do
      it 'returns a success response' do
        post :create, params: { user: { login_key: user.email, password: user.password } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
      end
    end

    context 'with valid username and password' do
      it 'signs in the user and returns a success response' do
        post :create, params: { user: { login_key: user.username, password: user.password } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['username']).to eq(user.username)
      end
    end

    context 'with invalid login credentials' do
      it 'returns an unauthorized response' do
        post :create, params: { user: { login_key: 'wronglogin', password: 'wrongpassword' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_SIGN_IN)
        expect(json_response['status']['error']).to eq(Messages::USER_NOT_FOUND)
      end
    end

    context 'with invalid password' do
      it 'returns an unauthorized response' do
        post :create, params: { user: { login_key: user.email, password: 'wrong_password' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_SIGN_IN)
        expect(json_response['status']['error']).to eq(Messages::INVALID_LOGIN_CREDENTIALS)
      end
    end

    context 'with unconfirmed user' do
      let(:unconfirmed_user) { create(:user, username: 'unconfirmeduser', email: 'unconfirmed@example.com', password: 'password') }

      it 'sends confirmation instructions and returns a success response' do
        post :create, params: { user: { login_key: unconfirmed_user.email, password: unconfirmed_user.password } }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::VERIFICATION_EMAIL_SENT.call(unconfirmed_user.email))
      end
    end

    context 'with Google registered email' do
      it 'returns an unauthorized response' do
        post :create, params: { user: { login_key: google_user.email, password: 'password' } }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_SIGN_IN)
        expect(json_response['status']['error']).to eq(Messages::USER_ALREADY_REGISTERED_WITH_GOOGLE.call(google_user.email))
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
        "picture" => "https://google_picture_url"
      }
    end

    before do
      allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info)
      allow(controller).to receive(:get_google_user_info).with(invalid_google_token).and_return(nil)
    end

    context 'with valid Google token and existing user' do
      let!(:google_user) { create(:user, email: google_user_info['email'], provider: 'google', password: 'password', password_confirmation: 'password', confirmed_at: Time.now) }
      it 'signs in the user and returns a success response' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(google_user.email)
        expect(json_response['data']['user']['username']).to eq(google_user.username)
      end
    end

    context 'with valid Google token and new user' do
      it 'creates a new user and returns a success response' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:created)
        expect(json_response['status']['code']).to eq(201)
        expect(json_response['data']['user']['email']).to eq(google_user_info['email'])
        expect(json_response['data']['user']['username']).to eq(google_user_info["email"].split("@").first)
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

    context 'with existing email registered with email provider' do
      let!(:existing_user) { create(:user, email: google_user_info['email'], password: 'password', password_confirmation: 'password', confirmed_at: Time.now) }
      it 'returns an unauthorized response' do
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['message']).to eq(Messages::GOOGLE_AUTHENTICATION_FAILED)
        expect(json_response['status']['error']).to eq(Messages::USER_ALREADY_REGISTERED_WITH_EMAIL.call(existing_user.email))
      end
    end

    context 'with various email formats' do
      it 'sanitizes email and creates a new user' do
        emails = [
          'john.doe@example.com',
          'Jane-Doe123@example.com',
          'user+alias@example.com',
          'user.name@domain.com',
          'user@domain.com'
        ]

        emails.each do |email|
          allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info.merge("email" => email))
          post :google_sign_in, params: { token: valid_google_token }
          expect(response).to have_http_status(:created)
          sanitized_username = email.split('@').first.downcase.gsub(/[^a-z0-9_]/, '_')
          expect(json_response['data']['user']['username']).to start_with(sanitized_username)
        end
      end

      it 'appends a random number if sanitized username already exists' do
        create(:user, username: 'existing_user')
        allow(controller).to receive(:get_google_user_info).with(valid_google_token).and_return(google_user_info.merge("email" => 'existing.user@example.com'))
        post :google_sign_in, params: { token: valid_google_token }
        expect(response).to have_http_status(:created)
        expect(json_response['data']['user']['username']).to match(/^existing_user_\d{6}$/)
      end
    end
  end
end
