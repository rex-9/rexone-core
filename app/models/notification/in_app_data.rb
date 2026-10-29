# frozen_string_literal: true

# app/models/notification/in_app_data.rb
# Deterministic payload contract for Notification in-app delivery.
class Notification
  class InAppData < ApplicationMetadata
    # Deep link or navigation route for client interaction.
    attribute :link, :string

    # Action identifier triggered when user taps notification (e.g. "open_room", "view_receipt").
    attribute :action, :string

    # Target entity type for navigation (e.g. "chat_room", "subscription").
    attribute :target_type, :string

    # Target entity UUID.
    attribute :target_id, :string

    # Asset name or URI for the notification icon.
    attribute :icon, :string

    # Audio cue or sound filename played on device alert.
    attribute :sound, :string

    # User display name for UI rendering.
    attribute :user_name, :string

    # User email address.
    attribute :user_email, :string
  end
end
