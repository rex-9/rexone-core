# frozen_string_literal: true

# app/services/payment/iap_service.rb
module Payment
  class IapService
    class << self
      def verify_and_provision(user:, product:, provider:, transaction_id: nil, purchase_token: nil, receipt_data: nil, package_name: nil, coupon_code: nil, raw_payload: {})
        provider_name = provider.to_s.downcase

        unless PaymentConstants::Provider::ALL.include?(provider_name)
          return { error: MessageService::Payment.t(MessageService::Payment::UNSUPPORTED_PROVIDER, provider: provider) }
        end

        # Free products cannot be purchased through in-app stores
        if product.free?
          return { error: MessageService::Payment.t(MessageService::Payment::FREE_PRODUCT_NOT_SUPPORTED) }
        end

        unless product.in_app?
          return { error: MessageService::Payment.t(MessageService::Payment::IN_APP_NOT_SUPPORTED) }
        end

        case provider_name
        when PaymentConstants::Provider::GOOGLE_PLAY
          unless product.available_on_google_play?
            return { error: MessageService::Payment.t(MessageService::Payment::GOOGLE_PLAY_NOT_SUPPORTED) }
          end
        when PaymentConstants::Provider::APP_STORE
          unless product.available_on_app_store?
            return { error: MessageService::Payment.t(MessageService::Payment::APP_STORE_NOT_SUPPORTED) }
          end
        end

        # Validate coupon upfront if supplied
        coupon = nil
        validation = nil
        if coupon_code.present?
          validation = CouponService.validate(
            user: user,
            product: product,
            code: coupon_code
          )

          unless validation[:valid]
            return {
              error: validation[:error] || MessageService::Payment::COUPON_INVALID,
              coupon_error: true
            }
          end

          coupon = validation[:coupon]
        end

        result = Providers::Client.verify_purchase(
          provider: provider_name,
          user: user,
          product: product,
          transaction_id: transaction_id,
          purchase_token: purchase_token,
          receipt_data: receipt_data,
          package_name: package_name,
          raw_payload: raw_payload
        )

        response_data = {
          success: true,
          verified: true,
          product_id: product.id,
          provider: provider_name,
          purchase: result[:purchase],
          subscription: result[:subscription],
          access: result[:access]
        }

        # If coupon was validly supplied and purchase/subscription verified, record coupon redemption
        if coupon.present?
          payment_record = result[:purchase] || result[:subscription]
          payment_type = result[:purchase] ? :purchase : :subscription

          CouponService.apply_to_checkout!(
            user: user,
            product: product,
            coupon: coupon,
            payment_id: payment_record.id,
            payment_type: payment_type
          )

          response_data[:coupon_code] = coupon.code
          response_data[:discount_amount] = validation[:discount_amount]
          response_data[:final_amount] = validation[:final_amount]
        end

        response_data
      rescue Providers::VerificationError => e
        { error: e.message }
      rescue Providers::Error => e
        { error: e.message }
      rescue => e
        Rails.logger.error("[IAP] Purchase verification failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        { error: MessageService::Payment.t(MessageService::Payment::VERIFICATION_FAILED) }
      end
    end
  end
end
