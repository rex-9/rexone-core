# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "OpenAPI V1 document" do
  subject(:document) { RSpec.configuration.openapi_specs.fetch("v1/swagger.yaml") }

  it "documents every intentional public API operation" do
    documented = document[:paths].flat_map do |path, methods|
      methods.keys.map { |method| [ method.to_s.upcase, path ] }
    end
    routed = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next unless path.start_with?("/v1")

      [ route.verb.to_s, path.gsub(/:([a-zA-Z_]+)/, '{\1}') ]
    end.uniq
    missing = routed.reject do |verb, path|
      documented.include?([ verb, path ]) ||
        (verb == "PUT" && documented.include?([ "PATCH", path ])) ||
        (verb == "PATCH" && documented.include?([ "PUT", path ]))
    end

    expect(missing).to be_empty, "Missing OpenAPI operations:\n#{missing.sort.map { |pair| pair.join(' ') }.join("\n")}"
    expect(document[:paths]).to include(
      "/signup",
      "/v1/payment/session",
      "/v1/payment/coupons/validate",
      "/v1/admin/payment/coupons",
      "/v1/admin/payment/user_coupons",
      "/v1/chat/messages",
      "/v1/admin/ai/profiles",
      "/v1/admin/ai/runs",
      "/v1/speech/tts",
      "/v1/speech/stt",
      "/v1/admin/accesses",
      "/v1/admin/user_notifications",
      "/v1/admin/feedbacks",
      "/v1/admin/analytics/overview",
      "/v1/admin/assets",
      "/v1/admin/assets/{id}/compress",
      "/v1/admin/client/versions",
      "/v1/admin/client/versions/user_versions",
      "/v1/client/versions/current",
      "/v1/client/versions/user-version",
      "/v1/feedbacks",
      "/v1/assets",
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

  it "uses explicit response contracts for current-user and queued-operation endpoints" do
    expected = {
      [ "/v1/users/current", :get ] => :current_user_response,
      [ "/v1/users/current", :put ] => :current_user_response,
      [ "/v1/admin/assets/{id}/compress", :post ] => :asset_operation_response,
      [ "/v1/admin/assets/{id}/thumbnail/regenerate", :post ] => :asset_operation_response,
      [ "/v1/chat/messages", :post ] => :ai_chat_response
    }

    expected.each do |(path, method), schema|
      success_response = document.dig(:paths, path, method, :responses).values_at("200", "202").compact.first
      expect(success_response.dig(:content, Openapi::V1::JSON_CONTENT, :schema)).to eq(Openapi::V1.ref(schema))
    end
  end

  it "documents query parameters for AI admin profiles and runs" do
    profile_params = document.dig(:paths, "/v1/admin/ai/profiles", :get, :parameters).map { |p| p[:name].to_sym }
    expect(profile_params).to include(:search, :provider, :model, :status, :enabled, :page, :limit, :sort_by, :sort_order)

    run_params = document.dig(:paths, "/v1/admin/ai/runs", :get, :parameters).map { |p| p[:name].to_sym }
    expect(run_params).to include(:search, :feature, :status, :provider, :model, :profile_id, :user_id, :page, :limit, :sort_by, :sort_order)

    tag_names = document[:tags].map { |t| t[:name] }
    expect(tag_names).to include("Admin / AI", "Chat")
  end

  it "documents sort and search parameters across all sortable and searchable endpoints" do
    sortable_endpoints = [
      "/v1/admin/users",
      "/v1/admin/iam/roles",
      "/v1/admin/payment/products",
      "/v1/admin/payment/coupons",
      "/v1/admin/payment/user_coupons",
      "/v1/admin/payment/transactions",
      "/v1/admin/payment/subscriptions",
      "/v1/admin/accesses",
      "/v1/admin/assets",
      "/v1/admin/feedbacks",
      "/v1/admin/client/versions",
      "/v1/admin/client/versions/user_versions",
      "/v1/admin/chat/rooms",
      "/v1/admin/chat/messages",
      "/v1/client/logs",
      "/v1/admin/ai/profiles",
      "/v1/admin/ai/runs"
    ]

    sortable_endpoints.each do |path|
      params = document.dig(:paths, path, :get, :parameters)&.map { |p| p[:name].to_sym } || []
      expect(params).to include(:sort_by, :sort_order), "#{path} is missing sort parameters in OpenAPI"
    end

    searchable_endpoints = [
      "/v1/admin/users",
      "/v1/admin/payment/coupons",
      "/v1/admin/payment/user_coupons",
      "/v1/admin/payment/transactions",
      "/v1/admin/payment/subscriptions",
      "/v1/admin/accesses",
      "/v1/admin/assets",
      "/v1/admin/feedbacks",
      "/v1/admin/notifications",
      "/v1/admin/ai/profiles",
      "/v1/admin/ai/runs"
    ]

    searchable_endpoints.each do |path|
      params = document.dig(:paths, path, :get, :parameters)&.map { |p| p[:name].to_sym } || []
      expect(params).to include(:search), "#{path} is missing search parameter in OpenAPI"
    end
  end
end

