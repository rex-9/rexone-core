# frozen_string_literal: true

# app/models/client/version/metadata.rb
# Deterministic metadata contract for Client::Version.
module Client
  class Version
    class Metadata < ApplicationMetadata
      # User-facing changelog or release description explaining updates in this version.
      attribute :release_notes, :string

      # Minimum operating system version required to run this client build (e.g. "16.0" for iOS, "12.0" for Android).
      attribute :min_os_version, :string

      # Flag indicating whether users on older builds must be blocked until they update.
      attribute :force_update, :boolean, default: false

      validates :min_os_version, format: { with: /\A\d+(\.\d+)*\z/, message: "must be a valid semantic version string" }, allow_nil: true
    end
  end
end
