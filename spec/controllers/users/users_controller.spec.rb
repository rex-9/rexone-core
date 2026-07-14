# spec/controllers/users/users_controller_spec.rb
require 'rails_helper'

RSpec.describe Users::UsersController, type: :controller do
  let(:user) { create(:user) }

  describe 'GET #get_current_user' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns current user' do
        get :get_current_user
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user']['email']).to eq(user.email)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get :get_current_user
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['status']['code']).to eq(401)
        expect(json_response['status']['error']).to eq('No current user found.')
      end
    end

    context 'with invalid session' do
      let(:user) { create(:user, jti: 'old_jti') }

      it 'returns 401' do
        # Simulate expired session
        sign_in user
        user.update(jti: 'new_jti')
        get :get_current_user
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #peek_user' do
    context 'with valid email' do
      before { create(:user, email: 'test@example.com') }

      it 'returns user_exists: true' do
        get :peek_user, params: { email: 'test@example.com' }
        expect(response).to have_http_status(:ok)
        expect(json_response['status']['code']).to eq(200)
        expect(json_response['data']['user_exists']).to be true
        expect(json_response['data']['confirmed']).to be true
      end

      it 'returns user_exists: false for non-existent email' do
        get :peek_user, params: { email: 'nonexistent@example.com' }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user_exists']).to be false
      end
    end

    context 'with unconfirmed user' do
      let!(:unconfirmed_user) { create(:user, :unconfirmed) }

      it 'returns confirmed: false' do
        get :peek_user, params: { email: unconfirmed_user.email }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user_exists']).to be true
        expect(json_response['data']['confirmed']).to be false
      end
    end

    context 'with blank email' do
      it 'returns 400' do
        get :peek_user, params: { email: '' }
        expect(response).to have_http_status(:bad_request)
        expect(json_response['status']['code']).to eq(400)
        expect(json_response['status']['error']).to eq('Missing email address.')
      end
    end

    context 'with email case insensitivity' do
      before { create(:user, email: 'test@example.com') }

      it 'finds user regardless of case' do
        get :peek_user, params: { email: 'TEST@EXAMPLE.COM' }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user_exists']).to be true
      end
    end

    context 'with whitespace in email' do
      before { create(:user, email: 'test@example.com') }

      it 'trims whitespace' do
        get :peek_user, params: { email: '  test@example.com  ' }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user_exists']).to be true
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end