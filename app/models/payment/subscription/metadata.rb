# frozen_string_literal: true

# app/models/payment/subscription/metadata.rb
# Deterministic metadata contract for Payment::Subscription entities.
module Payment
  class Subscription
    class Metadata < ApplicationMetadata
      # Identifier or promotional code of the discount coupon applied to this subscription.
      attribute :coupon_id, :string

      # Standard provider cancellation reason (e.g. Stripe 'cancellation_requested', 'customer_service').
      attribute :cancel_reason, :string
    end
  end
end
