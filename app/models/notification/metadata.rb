# frozen_string_literal: true

# app/models/notification/metadata.rb
# Deterministic metadata contract for Notification templates and dispatches.
class Notification
  class Metadata < ApplicationMetadata
    # Notification template type or event classifier (e.g. "payment_succeeded", "welcome").
    attribute :type, :string

    # Recipient user's display name for email/push interpolation.
    attribute :user_name, :string

    # Recipient user's email address.
    attribute :user_email, :string

    # Associated product name if transaction-related.
    attribute :product_name, :string

    # Formatted expiration or renewal date string.
    attribute :active_until, :string

    # Formatted monetary transaction amount.
    attribute :amount, :string

    # ISO currency code (e.g. "USD", "EUR").
    attribute :currency, :string

    # Deep link or action target URL for client navigation.
    attribute :link, :string

    # Correlated notification record UUID.
    attribute :notification_id, :string
  end
end
