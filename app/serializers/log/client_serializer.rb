# app/serializers/log/client_serializer.rb
class Log::ClientSerializer < ApplicationSerializer
  attributes :id, :message, :severity, :context, :stack_trace,
             :local_storage_keys, :session_storage_keys, :cookies,
             :platform, :environment, :app_version, :browser, :user_agent,
             :url, :method, :request_id,
             :resolved_at, :occurrence_count, :last_occurred_at,
             :created_at, :updated_at, :user_id, :created_by_id, :updated_by_id

  # ===== CUSTOM ATTRIBUTES =====
  attribute :formatted_context, &:formatted_context
  attribute :display_name, &:display_name
  attribute :storage_snapshot, &:storage_snapshot
  attribute :has_storage_issues, &:has_storage_issues?
  attribute :resolved, &:resolved?

  # ===== ASSOCIATIONS =====
  # belongs_to :user, serializer: UserSerializer, optional: true
  # belongs_to :resolved_by, serializer: UserSerializer, optional: true
end
