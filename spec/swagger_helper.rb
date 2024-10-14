# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1'
      },
      components: {
        schemas: {
          user: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              email: { type: :string },
              name: { type: :string, nullable: true },
              provider: { type: :string },
              photo: { type: :string, nullable: true },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: [ 'id', 'email', 'provider', 'created_at', 'updated_at' ]
          },
          success_status: {
            type: :object,
            properties: {
              code: { type: :integer, example: 200 },
              success: { type: :boolean },
              message: { type: :string }
            },
            required: [ 'code', 'success', 'message' ]
          },
          error_status: {
            type: :object,
            properties: {
              code: { type: :integer },
              success: { type: :boolean, example: false },
              message: { type: :string },
              error: { type: :string }
            },
            required: [ 'code', 'success', 'message', 'error' ]
          }
        },
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT
          }
        }
      },
      paths: {},
      servers: [
        {
          url: 'https://{defaultHost}', # TODO: Update the host accordingly
          variables: {
            defaultHost: {
              default: 'www.example.com' # TODO: Update the domain accordingly
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
