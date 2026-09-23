# app/serializers/log/client_serializer.rb
class Client::LogSerializer < ApplicationSerializer
  attributes :id, :message, :severity, :context, :stack_trace,
             :local_storage_keys, :session_storage_keys, :cookies,
             :platform, :environment, :version_id,
             :browser, :os, :os_version, :device, :user_agent,
             :url, :method, :request_id,
             :resolved_at, :occurrence_count, :last_occurred_at,
             :created_at, :updated_at, :user_id, :created_by_id, :updated_by_id

  # ===== CUSTOM ATTRIBUTES =====
  attribute :app_version do |log_client|
    log_client.version&.number
  end

  attribute :formatted_context, &:formatted_context
  attribute :display_name, &:display_name
  attribute :storage_snapshot, &:storage_snapshot
  attribute :has_storage_issues, &:has_storage_issues?
  attribute :resolved, &:resolved?
  attribute :unauthenticated, &:unauthenticated?
  attribute :authenticated, &:authenticated?

  # ===== ASSOCIATIONS =====
  # belongs_to :user, serializer: UserSerializer, optional: true
  # belongs_to :resolved_by, serializer: UserSerializer, optional: true
end
