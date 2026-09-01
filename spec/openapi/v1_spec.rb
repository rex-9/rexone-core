# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "OpenAPI V1 document" do
  subject(:document) { RSpec.configuration.openapi_specs.fetch("v1/swagger.yaml") }

  it "documents every intentional public API operation" do
    operation_count = document[:paths].sum { |_path, methods| methods.size }

    expect(operation_count).to eq(98)
    expect(document[:paths]).to include(
      "/signup",
      "/v1/payment/session",
      "/v1/ai/chat",
      "/v1/speech/tts",
      "/v1/speech/stt",
      "/v1/admin/analytics/overview",
      "/v1/feedbacks",
      "/v1/admin/feedbacks",
      "/webhooks/stripe"
    )
  end

  it "defines valid security references and response schemas" do
    expect(document.dig(:components, :securitySchemes, :bearerAuth)).to include(
      type: :http,
      scheme: :bearer
    )

    document[:paths].each_value do |methods|
      methods.each_value do |operation|
        expect(operation[:responses]).not_to be_empty
        expect(operation[:tags]).not_to be_empty
      end
    end
  end

  it "only publishes operations backed by real controller actions" do
    document[:paths].each do |path, methods|
      concrete_path = path.gsub(/\{[^}]+\}/, SecureRandom.uuid)

      methods.each_key do |method|
        route = Rails.application.routes.recognize_path(concrete_path, method: method)
        controller = "#{route.fetch(:controller)}_controller".camelize.constantize

        expect(controller.action_methods).to include(route.fetch(:action)),
          "#{method.to_s.upcase} #{path} points to missing " \
          "#{controller}##{route.fetch(:action)}"
      end
    end
  end

  it "groups versioned admin operations under admin tags" do
    admin_paths = document[:paths].select { |path, _methods| path.start_with?("/v1/admin/") }

    admin_paths.each_value do |methods|
      methods.each_value do |operation|
        expect(operation.fetch(:tags)).to all(start_with("Admin /"))
      end
    end
  end

  it "uses named schemas for every client-authored request object" do
    document[:paths].each do |path, methods|
      methods.each do |method, operation|
        operation.fetch(:requestBody, {}).fetch(:content, {}).each do |content_type, media_type|
          next if path == "/webhooks/stripe"

          expect(media_type.fetch(:schema)).to include(:"$ref"),
            "#{method.to_s.upcase} #{path} (#{content_type}) must reference a named request schema"
        end
      end
    end
  end

  it "documents conditional notification audiences and AI metadata keys" do
    notification = document.dig(:components, :schemas, :notification_request, :properties)
    audience_variants = notification.dig(:audience, :oneOf)

    expect(audience_variants.map { |variant| variant.dig(:properties, :type, :enum) })
      .to contain_exactly([ "users" ], [ "roles" ], [ "all" ])
    expect(notification.dig(:channels, :items, :enum)).to eq(NotificationService::Center::CHANNELS)

    metadata = document.dig(:components, :schemas, :ai_message_metadata, :properties)
    expect(metadata.keys).to contain_exactly(
      :status,
      :system_prompt,
      :temperature,
      :max_tokens,
      :assistant_message_id,
      :error,
      :usage,
      :model,
      :tts_status,
      :tts_error
    )
    expect(metadata.dig(:status, :enum)).to eq(Chat::Message::STATUSES.values)
    expect(metadata.dig(:tts_status, :enum)).to eq(Chat::Message::STATUSES.values)
  end
end
