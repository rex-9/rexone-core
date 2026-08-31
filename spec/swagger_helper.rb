# frozen_string_literal: true

require 'rails_helper'
require_relative 'openapi/v1'

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
        title: 'Rexone Core API',
        version: 'v1',
        description: <<~DESCRIPTION
          Production API foundation for authentication, IAM, payments, access,
          media, notifications, client observability, and AI conversations.

          Authenticated endpoints use a bearer JWT. Send `X-Platform` as `web`,
          `android`, or `ios` to select the active session, and `X-Locale` as
          `en`, `my`, or `es` to select translated response messages.
        DESCRIPTION
      },
      tags: [
        { name: 'Authentication', description: 'Account registration, confirmation, sessions, and password recovery.' },
        { name: 'Users', description: 'Authenticated user profile and effective IAM information.' },
        {
          name: 'Admin / Users',
          description: 'Admin dashboard user operations. Requires the admin role and the matching user permission.'
        },
        {
          name: 'Admin / Notifications',
          description: 'Admin notification dispatch. Requires the admin role and create_notifications permission.'
        },
        { name: 'IAM Permissions', description: 'Super-admin permission management.' },
        { name: 'IAM Roles', description: 'Role definitions and their permission assignments.' },
        { name: 'IAM User Roles', description: 'Admin-managed role assignments for users.' },
        { name: 'Payments', description: 'Products, checkout sessions, subscriptions, and transactions.' },
        { name: 'Access', description: 'Product-access inspection and revocation.' },
        { name: 'Media', description: 'Synchronous multipart asset upload.' },
        { name: 'AI', description: 'Durable queued chat plus synchronous text utilities.' },
        { name: 'Speech', description: 'Text-to-speech synthesis and speech-to-text transcription.' },
        { name: 'Client Logs', description: 'Client error ingestion and authorized operational review.' },
        { name: 'Webhooks', description: 'Provider-signed inbound webhooks.' }
      ],
      components: {
        schemas: Openapi::V1::SCHEMAS,
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT
          }
        }
      },
      paths: Openapi::V1::PATHS,
      servers: [
        {
          url: '/',
          description: 'Current API server'
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
