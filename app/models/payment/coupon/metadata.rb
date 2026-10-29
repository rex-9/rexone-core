# frozen_string_literal: true

# app/models/payment/coupon/metadata.rb
# Deterministic metadata contract for Payment::Coupon synchronization lifecycle.
module Payment
  class Coupon
    class Metadata < ApplicationMetadata
      # Current synchronization state with payment provider ('pending', 'processing', 'succeeded', 'failed').
      attribute :status, :string

      # Detailed error message returned by the provider if synchronization failed.
      attribute :sync_error, :string

      # ISO 8601 timestamp recording when remote synchronization failed.
      attribute :failed_at, :string

      # ISO 8601 timestamp recording when remote synchronization succeeded.
      attribute :synced_at, :string

      validates :status, inclusion: { in: PaymentConstants::SyncStatus::ALL }, allow_nil: true

      def pending?
        status == PaymentConstants::SyncStatus::PENDING
      end

      def processing?
        status == PaymentConstants::SyncStatus::PROCESSING
      end

      def succeeded?
        status == PaymentConstants::SyncStatus::SUCCEEDED
      end

      def failed?
        status == PaymentConstants::SyncStatus::FAILED
      end
    end
  end
end
