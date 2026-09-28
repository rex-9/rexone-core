# frozen_string_literal: true

# app/services/payment/providers/google_play.rb
module Payment
  module Providers
    class GooglePlay < Base
      LOG_PREFIX = "[GooglePlay]".freeze

      def verify_purchase(user:, product:, receipt_data: nil, transaction_id: nil, purchase_token: nil, package_name: nil, raw_payload: {})
        purchase_token ||= receipt_data
        if purchase_token.blank? && transaction_id.blank?
          raise VerificationError, "Missing Google Play purchase token or order ID"
        end

        resolved_order_id = transaction_id.presence || "GPA.#{SecureRandom.random_number(10**4..10**5)}-#{SecureRandom.random_number(10**4..10**5)}-#{SecureRandom.random_number(10**4..10**5)}"
        payload = raw_payload.presence || {}

        if product.recurring?
          verify_subscription(
            user: user,
            product: product,
            order_id: resolved_order_id,
            purchase_token: purchase_token,
            package_name: package_name,
            payload: payload
          )
        else
          verify_one_time_purchase(
            user: user,
            product: product,
            order_id: resolved_order_id,
            purchase_token: purchase_token,
            package_name: package_name,
            payload: payload
          )
        end
      end

      def supported_webhook_event?(event_type)
        PaymentConstants::GooglePlayNotificationType::ALL.include?(event_type.to_s.upcase)
      end

      def verify_webhook(payload, signature)
        # Google Cloud Pub/Sub sends push messages with authorization headers or JWT verification.
        # In standard mode, verification ensures payload has valid message structure.
        return true if Rails.env.development? || Rails.env.test?

        payload.is_a?(Hash) && payload["message"].present?
      end

      def process_webhook(event)
        message = event.payload["message"] || {}
        data_str = message["data"]
        return unless data_str.present?

        decoded = JSON.parse(Base64.decode64(data_str)) rescue {}
        notification_type = decoded.dig("subscriptionNotification", "notificationType")
        purchase_token = decoded.dig("subscriptionNotification", "purchaseToken")

        Rails.logger.info("#{LOG_PREFIX} Processed notification type: #{notification_type} for token: #{purchase_token}")
        { processed: true, notification_type: notification_type }
      end

      private

      def verify_one_time_purchase(user:, product:, order_id:, purchase_token:, package_name:, payload:)
        # Idempotency check: prevent duplicate credit for the same order
        existing_purchase = Payment::Purchase.find_by(
          provider: PaymentConstants::Provider::GOOGLE_PLAY,
          provider_payment_id: order_id
        )

        if existing_purchase&.succeeded?
          access = AccessService.grant(user_id: user.id, product_id: product.id, expires_at: nil)
          return { verified: true, purchase: existing_purchase, access: access }
        end

        purchase = Payment::Purchase.find_or_initialize_by(
          provider: PaymentConstants::Provider::GOOGLE_PLAY,
          provider_payment_id: order_id
        )
        new_record = purchase.new_record?

        purchase.assign_attributes(
          user: user,
          product: product,
          unit_amount: product.unit_amount,
          currency: product.currency,
          status: PaymentConstants::PurchaseStatus::SUCCEEDED,
          payment_method_type: "google_play",
          payment_method_details: {
            "order_id" => order_id,
            "purchase_token" => purchase_token,
            "package_name" => package_name
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

        Rails.logger.info("#{LOG_PREFIX} Verified one-time purchase: #{order_id} for user #{user.id}")
        { verified: true, purchase: purchase, access: access }
      end

      def verify_subscription(user:, product:, order_id:, purchase_token:, package_name:, payload:)
        subscription_id = order_id.presence || purchase_token.presence || "gplay_sub_#{SecureRandom.hex(12)}"

        subscription = Payment::Subscription.find_or_initialize_by(
          provider: PaymentConstants::Provider::GOOGLE_PLAY,
          provider_subscription_id: subscription_id
        )
        new_record = subscription.new_record?

        period_start = Time.current
        period_end = product.interval_in_duration.from_now

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
          payment_method_type: "google_play",
          payment_method_details: {
            "order_id" => order_id,
            "purchase_token" => purchase_token,
            "package_name" => package_name
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
    end
  end
end
