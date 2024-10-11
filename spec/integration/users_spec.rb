require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  path '/users/current' do
    get 'Get current user' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'current user fetched successfully' do
        schema type: :object,
          properties: {
            status: { '$ref' => '#/components/schemas/success_status' },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/user' }
              },
              required: [ 'user' ]
            }
          },
          required: [ 'status', 'data' ]

        let(:user) { create(:user) }
        let(:token) { AppConfig::JWT_TOKEN.call(user) }
        let(:Authorization) { "Bearer #{token}" }
        run_test!
      end

      response '401', 'unauthorized' do
        schema type: :object,
          properties: {
            status: {
              type: :object,
              properties: {
                code: { type: :integer },
                message: { type: :string },
                error: { type: :string }
              },
              required: [ 'code', 'message', 'error' ]
            }
          },
          required: [ 'status' ]
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/signin' do
    post 'Sign in a user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string },
              password: { type: :string }
            },
            required: [ 'email', 'password' ]
          }
        },
        required: [ 'user' ]
      }

      response '200', 'signed in successfully' do
        schema type: :object,
          properties: {
            status: { '$ref' => '#/components/schemas/success_status' },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/user' },
                token: { type: :string }
              },
              required: [ 'user', 'token' ]
            }
          },
          required: [ 'status', 'data' ]

        let(:existing_user) { create(:user, email: 'existing@user.com', password: 'password', confirmed_at: Time.now) }
        let(:user) { { user: { email: existing_user.email, password: existing_user.password } } }
        run_test!
      end

      response '401', 'failed to sign in' do
        schema type: :object,
          properties: {
            status: { '$ref' => '#/components/schemas/error_status' }
          },
          required: [ 'status' ]

        let(:user) { { user: { email: 'nonexistent@user.com', password: 'wrongpassword' } } }
        run_test!
      end
    end
  end

  path '/signin/token' do
    post 'Sign in a user with a token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :token, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string }
        },
        required: [ 'token' ]
      }

      response '200', 'signed in successfully' do
        schema type: :object,
          properties: {
            status: { '$ref' => '#/components/schemas/success_status' },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/user' },
                token: { type: :string }
              },
              required: [ 'user', 'token' ]
            }
          },
          required: [ 'status', 'data' ]

        let(:token_user) { create(:user, email: 'token@user.com', password: 'password', confirmed_at: Time.now) }
        let(:token) { { token: token_user.jti } }
        run_test!
      end

      response '401', 'invalid authentication token' do
        schema type: :object,
          properties: {
            status: { '$ref' => '#/components/schemas/error_status' }
          },
          required: [ 'status' ]

        let(:token) { { token: 'invalidtoken' } }
        run_test!
      end
    end
  end

  path '/signin/google' do
    post 'Sign in a user with a Google token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :token, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string }
        },
        required: [ 'token' ]
      }

      response '200', 'signed in successfully' do
        schema type: :object,
          properties: {
            status_code: { type: :integer },
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/user' },
                token: { type: :string }
              }
            }
          },
          required: [ 'status_code', 'message', 'data' ]
      end

      response '201', 'account created and signed in successfully' do
        schema type: :object,
          properties: {
            status_code: { type: :integer },
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                user: { type: :object },
                token: { type: :string }
              }
            }
          },
          required: [ 'status_code', 'message', 'data' ]
      end

      response '401', 'Google authentication failed' do
        schema type: :object,
          properties: {
            status: { '$ref' => '#/components/schemas/error_status' }
          },
          required: [ 'status' ]

        let(:token) { { token: 'invalidtoken' } }
        run_test!
      end
    end
  end

  path '/signup' do
    post 'Sign up a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string }
            },
            required: [ 'email', 'password', 'password_confirmation' ]
          }
        },
        required: [ 'user' ]
      }

      response '201', 'signed up successfully' do
        schema type: :object,
          properties: {
            status: {
              type: :object,
              properties: {
                code: { type: :integer, example: 201 },
                success: { type: :boolean },
                message: { type: :string, example: Messages::SIGNED_UP_SUCCESSFULLY }
              },
              required: [ 'code', 'success', 'message' ]
            },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/user' }
              },
              required: [ 'user' ]
            }
          },
          required: [ 'status', 'data' ]

        let(:user) { { user: { email: 'user@example.com', password: 'password', password_confirmation: 'password' } } }
        run_test!
      end

      response '422', 'failed to sign up' do
        schema type: :object,
          properties: {
            status: {
              type: :object,
              properties: {
                code: { type: :integer, example: 422 },
                success: { type: :boolean, example: false },
                message: { type: :string },
                error: { type: :string }
              },
              required: [ 'code', 'success', 'message', 'error' ]
            }
          },
          required: [ 'status' ]

        let(:user) { { user: { email: 'user@example.com', password: 'password', password_confirmation: 'mismatch' } } }
        run_test!
      end
    end
  end
end
