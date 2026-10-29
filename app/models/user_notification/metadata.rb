# frozen_string_literal: true

# app/models/user_notification/metadata.rb
# Deterministic metadata contract for UserNotification inbox entries.
class UserNotification
  class Metadata < ApplicationMetadata
    # Async operation or job correlation UUID (e.g. for media compression or AI task tracking).
    attribute :operation_id, :string

    # Category of background operation ('asset_compression', 'speech_generation', 'ai_pipeline').
    attribute :operation_type, :string

    # Status of background operation ('processing', 'completed', 'failed').
    attribute :operation_status, :string

    # Deep link for user navigation upon interaction.
    attribute :link, :string

    # Notification classification type (e.g. 'asset_compressed', 'payment_succeeded').
    attribute :type, :string

    # Originator source of the notification event ('system', 'stripe', 'worker').
    attribute :source, :string

    # Recipient user's display name.
    attribute :user_name, :string

    # Associated product name if transaction-related.
    attribute :product_name, :string

    # Expiration or renewal date string.
    attribute :active_until, :string

    # Formatted monetary amount.
    attribute :amount, :string

    # ISO currency code.
    attribute :currency, :string

    # Correlated asset UUID if media-related.
    attribute :asset_id, :string

    # Processing status string.
    attribute :status, :string

    # Processed file size in bytes.
    attribute :size_bytes, :integer

    # Direct URL to the referenced asset.
    attribute :url, :string

    # Correlated chat message UUID.
    attribute :message_id, :string

    # Array or list of correlated chat message UUIDs.
    attribute :message_ids

    # Correlated chat room UUID.
    attribute :room_id, :string

    # Correlated parent notification UUID.
    attribute :notification_id, :string

    # Associated purchase or store order ID.
    attribute :order_id, :string

    # Delivery channel ('socket', 'fcm', 'email').
    attribute :channel, :string

    # Thumbnail preview data or URL.
    attribute :thumbnail

    validates :operation_type, inclusion: { in: NotificationConstants::OperationType::ALL }, allow_nil: true
    validates :operation_status, inclusion: { in: NotificationConstants::OperationStatus::ALL }, allow_nil: true
  end
end
