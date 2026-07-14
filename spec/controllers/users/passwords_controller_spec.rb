# spec/controllers/users/passwords_controller_spec.rb
require 'rails_helper'

RSpec.describe Users::PasswordsController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'POST #create' do
    let(:user) { create(:user) }

    context 'with valid email' do
      it 'sends reset instructions' do
        expect {
          post :create, params: { email: user.email }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::PASSWORD_RESET_INSTRUCTIONS_SENT.call(user.email))
      end
    end

    context 'with non-existent email' do
      it 'returns 404' do
        post :create, params: { email: 'nonexistent@example.com' }
        expect(response).to have_http_status(:not_found)
        expect(json_response['status']['code']).to eq(404)
        expect(json_response['status']['error']).to eq(Messages::EMAIL_NOT_FOUND)
      end
    end

    context 'with Google provider user' do
      let(:google_user) { create(:user, :google_provider) }

      it 'still sends reset instructions' do
        post :create, params: { email: google_user.email }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
      end
    end
  end

  describe 'PUT #update' do
    let(:user) { create(:user) }
    let(:reset_token) { user.send(:set_reset_password_token) }

    context 'with valid token and matching passwords' do
      it 'resets password successfully' do
        put :update, params: {
          user: {
            reset_password_token: reset_token,
            password: 'newpassword123',
            password_confirmation: 'newpassword123'
          }
        }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['status']['message']).to eq(Messages::PASSWORD_RESET_SUCCESSFULLY)
        expect(user.reload.valid_password?('newpassword123')).to be true
      end
    end

    context 'with invalid token' do
      it 'returns error' do
        put :update, params: {
          user: {
            reset_password_token: 'invalid_token',
            password: 'newpassword123',
            password_confirmation: 'newpassword123'
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to be_present
      end
    end

    context 'with mismatched passwords' do
      it 'returns error' do
        put :update, params: {
          user: {
            reset_password_token: reset_token,
            password: 'newpassword123',
            password_confirmation: 'differentpassword'
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['error']).to include('confirmation')
      end
    end

    context 'with expired token' do
      it 'returns error' do
        travel_to 7.hours.from_now do
          put :update, params: {
            user: {
              reset_password_token: reset_token,
              password: 'newpassword123',
              password_confirmation: 'newpassword123'
            }
          }
          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['status']['code']).to eq(422)
        end
      end
    end
  end

  describe 'GET #edit' do
    let(:reset_token) { 'valid_token' }

    it 'redirects to frontend reset page' do
      get :edit, params: { reset_password_token: reset_token }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(/#{AppConfig::CLIENT_BASE_URL}\/password\/reset\?reset_password_token=#{reset_token}/)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end