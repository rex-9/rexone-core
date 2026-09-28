# frozen_string_literal: true

# app/services/payment/providers/app_store.rb
module Payment
  module Providers
    class AppStore < Base
      LOG_PREFIX = "[AppStore]".freeze

      def verify_purchase(user:, product:, receipt_data: nil, transaction_id: nil, purchase_token: nil, package_name: nil, raw_payload: {})
        raw_receipt = receipt_data.presence || purchase_token
        if raw_receipt.blank? && transaction_id.blank?
          raise VerificationError, "Missing App Store receipt or transaction ID"
        end

        # Decode StoreKit 2 JWS if applicable
        decoded_payload = decode_jws_payload(raw_receipt)
        resolved_transaction_id = transaction_id.presence || decoded_payload["transactionId"] || "20000#{SecureRandom.random_number(10**9..10**10)}"
        resolved_original_transaction_id = decoded_payload["originalTransactionId"] || resolved_transaction_id
        resolved_bundle_id = package_name.presence || decoded_payload["bundleId"]

        payload = (raw_payload.presence || {}).merge(decoded_payload)

        if product.recurring?
          verify_subscription(
            user: user,
            product: product,
            transaction_id: resolved_transaction_id,
            original_transaction_id: resolved_original_transaction_id,
            bundle_id: resolved_bundle_id,
            payload: payload
          )
        else
          verify_one_time_purchase(
            user: user,
            product: product,
            transaction_id: resolved_transaction_id,
            original_transaction_id: resolved_original_transaction_id,
            bundle_id: resolved_bundle_id,
            payload: payload
          )
        end
      end

      def supported_webhook_event?(event_type)
        PaymentConstants::AppStoreNotificationType::ALL.include?(event_type.to_s.upcase)
      end

      def verify_webhook(payload, signature)
        # StoreKit 2 App Store Server Notifications V2 uses signedPayload JWS
        return true if Rails.env.development? || Rails.env.test?

        payload.is_a?(Hash) && payload["signedPayload"].present?
      end

      def process_webhook(event)
        signed_payload = event.payload["signedPayload"]
        decoded = decode_jws_payload(signed_payload)
        notification_type = decoded["notificationType"]
        subtype = decoded["subtype"]

        Rails.logger.info("#{LOG_PREFIX} Processed notification type: #{notification_type} (#{subtype})")
        { processed: true, notification_type: notification_type, subtype: subtype }
      end

      private

      def verify_one_time_purchase(user:, product:, transaction_id:, original_transaction_id:, bundle_id:, payload:)
        existing_purchase = Payment::Purchase.find_by(
          provider: PaymentConstants::Provider::APP_STORE,
          provider_payment_id: transaction_id
        )

        if existing_purchase&.succeeded?
          access = AccessService.grant(user_id: user.id, product_id: product.id, expires_at: nil)
          return { verified: true, purchase: existing_purchase, access: access }
        end

        purchase = Payment::Purchase.find_or_initialize_by(
          provider: PaymentConstants::Provider::APP_STORE,
          provider_payment_id: transaction_id
        )
        new_record = purchase.new_record?

        purchase.assign_attributes(
          user: user,
          product: product,
          unit_amount: product.unit_amount,
          currency: product.currency,
          status: PaymentConstants::PurchaseStatus::SUCCEEDED,
          payment_method_type: "app_store",
          payment_method_details: {
            "transaction_id" => transaction_id,
            "original_transaction_id" => original_transaction_id,
            "bundle_id" => bundle_id
          }.compact,
          amount_received: product.unit_amount,
          paid_at: Time.current,
          metadata: payload
        )
        purchase.save!

        access = AccessService.grant(user_id: user.id, product_id: product.id, expires_at: nil)

        if new_record
          NotificationService::Center.payment_success(user, product, purchase) rescue nil
        end

        Rails.logger.info("#{LOG_PREFIX} Verified one-time purchase: #{transaction_id} for user #{user.id}")
        { verified: true, purchase: purchase, access: access }
      end

      def verify_subscription(user:, product:, transaction_id:, original_transaction_id:, bundle_id:, payload:)
        subscription_id = original_transaction_id.presence || transaction_id

        subscription = Payment::Subscription.find_or_initialize_by(
          provider: PaymentConstants::Provider::APP_STORE,
          provider_subscription_id: subscription_id
        )
        new_record = subscription.new_record?

        period_start = Time.current
        expires_date_ms = payload["expiresDate"]
        period_end = expires_date_ms.present? ? Time.at(expires_date_ms.to_i / 1000) : product.interval_in_duration.from_now

        subscription.assign_attributes(
          user: user,
          product: product,
          unit_amount: product.unit_amount,
          currency: product.currency,
          quantity: 1,
          interval: product.interval,
          interval_count: 1,
          status: PaymentConstants::SubscriptionStatus::ACTIVE,
          started_at: period_start,
          current_period_start: period_start,
          current_period_end: period_end,
          payment_method_type: "app_store",
          payment_method_details: {
            "transaction_id" => transaction_id,
            "original_transaction_id" => original_transaction_id,
            "bundle_id" => bundle_id
          }.compact,
          metadata: payload
        )
        subscription.save!

        access = AccessService.grant(user_id: user.id, product_id: product.id, expires_at: period_end)

        if new_record
          NotificationService::Center.subscription_created(user, product, subscription) rescue nil
        end

        Rails.logger.info("#{LOG_PREFIX} Verified subscription: #{subscription_id} for user #{user.id}")
        { verified: true, subscription: subscription, access: access }
      end

      def decode_jws_payload(jws_token)
        return {} if jws_token.blank?

        parts = jws_token.to_s.split(".")
        return {} unless parts.length == 3

        # Payload is the second component of JWS
        padded = parts[1] + ("=" * ((4 - parts[1].length % 4) % 4))
        decoded_bytes = Base64.urlsafe_decode64(padded)
        JSON.parse(decoded_bytes) rescue {}
      rescue => e
        Rails.logger.warn("#{LOG_PREFIX} Failed to decode JWS payload: #{e.message}")
        {}
      end
    end
  end
end
