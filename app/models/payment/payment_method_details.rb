# frozen_string_literal: true

# app/models/payment/payment_method_details.rb
# Polymorphic payment method snapshot persisted alongside Payment::Purchase and Payment::Subscription.
# Captures non-sensitive payment instrument details across our three payment providers:
#
# 1. Stripe (Web / Credit Card)
#    Populated by Payment::Providers::Stripe via Stripe::PaymentMethod (cards, Apple Pay / Google Pay on web).
#    Used in user settings, invoices, and receipts to display card brand (Visa, Mastercard) and expiration.
#
# 2. Google Play (Android In-App Purchases)
#    Populated by Payment::Providers::GooglePlay when verifying Google Play receipts.
#    Used for purchase acknowledgment, fraud audits, and Google refund lookups.
#
# 3. Apple App Store (iOS StoreKit In-App Purchases)
#    Populated by Payment::Providers::AppStore when verifying App Store receipts.
#    Used for App Store Server API dispute resolution and subscription chain auditing.
module Payment
  class PaymentMethodDetails < ApplicationMetadata
    # ===== STRIPE / CREDIT CARD ATTRIBUTES =====
    # Card brand (e.g. 'visa', 'mastercard', 'amex'). Used for card brand icons in billing UI.
    attribute :brand, :string

    # Last 4 digits of the card (e.g. '4242'). Rendered in user settings receipts ("Visa •••• 4242").
    attribute :last4, :string

    # Expiration month (1..12). Used to alert users when their subscription card is expiring.
    attribute :exp_month, :integer

    # Four-digit expiration year (>= 2000). Used to alert users when their card is expiring.
    attribute :exp_year, :integer

    # Two-letter ISO country code of the card issuer (e.g. 'US', 'SG'). Used for tax/compliance audits.
    attribute :country, :string

    # Payment method subtype returned by Stripe (e.g. 'card', 'us_bank_account').
    attribute :type, :string

    # Card funding category (e.g. 'credit', 'debit', 'prepaid').
    attribute :funding, :string

    # ===== GOOGLE PLAY (ANDROID) ATTRIBUTES =====
    # Google Play order identifier (e.g. 'GPA.3344-5566-7788-99000').
    attribute :order_id, :string

    # Opaque purchase token sent by Google Play Billing library. Required to verify purchase status.
    attribute :purchase_token, :string

    # Android application package name (e.g. 'com.rexone.app').
    attribute :package_name, :string

    # ===== APPLE APP STORE (IOS) ATTRIBUTES =====
    # App Store transaction identifier from StoreKit.
    attribute :transaction_id, :string

    # Original StoreKit transaction identifier that anchors subscription renewals across the user's lifetime.
    attribute :original_transaction_id, :string

    # iOS application bundle identifier (e.g. 'com.rexone.app').
    attribute :bundle_id, :string

    validates :exp_month, numericality: { only_integer: true, in: 1..12 }, allow_nil: true
    validates :exp_year, numericality: { only_integer: true, greater_than_or_equal_to: 2000 }, allow_nil: true
  end
end
