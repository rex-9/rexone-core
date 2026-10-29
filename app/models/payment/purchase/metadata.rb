# frozen_string_literal: true

# app/models/payment/purchase/metadata.rb
# Deterministic metadata contract for Payment::Purchase receipts.
module Payment
  class Purchase
    class Metadata < ApplicationMetadata
      # Identifier or promotional code of the discount coupon applied to this purchase.
      attribute :coupon_id, :string

      # External store order or transaction identifier (e.g. Apple StoreKit original transaction ID or Google Play order ID).
      attribute :order_id, :string
    end
  end
end
