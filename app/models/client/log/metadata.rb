# frozen_string_literal: true

# app/models/client/log/metadata.rb
# Deterministic metadata contract for Client::Log entries.
module Client
  class Log
    class Metadata < ApplicationMetadata
      # Semantic version of the client app reporting the log (e.g. "1.0.0").
      attribute :app_version, :string

      # UI or architectural component name where the event occurred (e.g. "auth_provider", "video_player").
      attribute :component, :string

      # Specific client action being executed when the log was captured (e.g. "login_click", "token_refresh").
      attribute :action, :string

      # API endpoint or network route involved in the log entry.
      attribute :endpoint, :string

      # Retry attempt number for transient network operations.
      attribute :attempt, :integer

      # UUID of the authenticated user if available when logging occurred.
      attribute :user_id, :string

      # HTTP status code returned by remote servers if applicable (e.g. 500, 401).
      attribute :status_code, :integer

      # Categorical error classification string (e.g. "NetworkError", "TimeoutError").
      attribute :error_type, :string
    end
  end
end
