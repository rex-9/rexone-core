require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:valid_attributes) do
    {
      user: {
        username: 'testusername',
        email: 'test@example.com',
        password: 'password',
        password_confirmation: 'password'
      }
    }
  end

  let(:invalid_attributes) do
    {
      user: {
        username: 'testusername',
        email: 'test@example.com',
        password: 'password',
        password_confirmation: 'wrong_password'
      }
    }
  end

  let(:google_user) { create(:user, email: 'google@example.com', provider: 'google') }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'POST #create' do
    context 'with valid attributes' do
      it 'creates a new user and returns a success response' do
        post :create, params: valid_attributes
        expect(response).to have_http_status(:created)
        expect(json_response['status']['code']).to eq(201)
        expect(json_response['data']['user']['email']).to eq('test@example.com')
      end
    end

    context 'with invalid attributes' do
      it 'returns an unprocessable entity response' do
        post :create, params: invalid_attributes
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
      end
    end

    context 'with email registered with Google' do
      it 'returns an unprocessable entity response' do
        post :create, params: { user: { email: google_user.email, password: 'password', password_confirmation: 'password' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['message']).to eq(Messages::FAILED_TO_SIGN_UP)
        expect(json_response['status']['error']).to eq(Messages::USER_ALREADY_REGISTERED_WITH_GOOGLE.call(google_user.email))
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it 'deletes the user and returns a success response' do
      delete :destroy
      expect(response).to have_http_status(:ok)
      expect(json_response['status']['code']).to eq(200)
      expect(json_response['status']['message']).to eq('Account deleted successfully.')
    end
  end
end
