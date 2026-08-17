# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "OpenAPI V1 document" do
  subject(:document) { RSpec.configuration.openapi_specs.fetch("v1/swagger.yaml") }

  it "documents every intentional public API operation" do
    operation_count = document[:paths].sum { |_path, methods| methods.size }

    expect(operation_count).to eq(67)
    expect(document[:paths]).to include(
      "/signup",
      "/v1/payment/session",
      "/v1/ai/chat",
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
end
