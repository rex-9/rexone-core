# frozen_string_literal: true

# app/services/coupon_service.rb
class CouponService
  LOG_PREFIX = "[CouponService]"

  class << self
    def validate(user:, product:, code:)
      normalized_code = code.to_s.strip.upcase
      coupon = Payment::Coupon.find_by(code: normalized_code)

      unless coupon
        return {
          valid: false,
          error: MessageService::Payment::COUPON_INVALID,
          code: normalized_code
        }
      end

      result = coupon.validate_applicability(user: user, product: product)
      if !result[:valid] && [
        MessageService::Payment::COUPON_NOT_FOUND,
        MessageService::Payment::COUPON_EXPIRED,
        MessageService::Payment::COUPON_USAGE_LIMIT_REACHED,
        MessageService::Payment::COUPON_USER_LIMIT_REACHED
      ].include?(result[:error])
        result[:error] = MessageService::Payment::COUPON_INVALID
      end

      result
    end

    def allowed?(user_id)
      cooldown_remaining(user_id) <= 0
    end

    def cooldown_remaining(user_id)
      cooldown_until = CacheService.read(cooldown_key(user_id)).to_i
      remaining = cooldown_until - Time.now.to_i
      remaining.positive? ? remaining : 0
    end

    def record_failure(user_id)
      attempts = CacheService.increment(attempts_key(user_id), 1, expires_in: 1.hour) || 1

      cooldown = case attempts
      when 1, 2   then 0
      when 3      then 30
      when 4, 5   then 0
      when 6      then 60
      when 7, 8   then 0
      when 9      then 120
      when 10, 11 then 0
      else             300
      end

      if cooldown.positive?
        cooldown_until = Time.now.to_i + cooldown
        CacheService.write(cooldown_key(user_id), cooldown_until, expires_in: cooldown + 5)
      end

      {
        remaining_attempts: cooldown.positive? ? 0 : 3 - (attempts % 3),
        cooldown_remaining: cooldown,
        locked: cooldown.positive?
      }
    end

    def record_success(user_id)
      CacheService.delete(attempts_key(user_id))
      CacheService.delete(cooldown_key(user_id))
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Failed to record success: #{e.message}")
    end

    def attempts_key(user_id)
      "coupon:attempts:#{user_id}"
    end

    def cooldown_key(user_id)
      "coupon:cooldown:#{user_id}"
    end

    def apply_to_checkout!(user:, product:, coupon:, purchase_id:, purchase_type:)
      ActiveRecord::Base.transaction do
        # Atomic increment with race condition protection
        updated_rows = Payment::Coupon.where(id: coupon.id)
                                      .where("max_usage = 0 OR max_usage IS NULL OR used_count < max_usage")
                                      .update_all("used_count = used_count + 1")

        if updated_rows.zero?
          raise PaymentService::Error, MessageService::Payment.t(MessageService::Payment::COUPON_USAGE_LIMIT_REACHED)
        end

        discount_info = coupon.calculate_discount(product)

        Payment::UserCoupon.create!(
          coupon: coupon,
          user: user,
          product: product,
          purchase_id: purchase_id,
          purchase_type: purchase_type,
          discount_amount: discount_info[:discount_amount],
          original_amount: product.unit_amount.to_i,
          final_amount: discount_info[:final_amount],
          currency: product.currency
        )
      end
    end

    def ensure_stripe_coupon(coupon)
      return coupon.stripe_coupon_id if coupon.stripe_coupon_id.present?

      stripe_params = {
        id: coupon.code,
        name: coupon.title,
        duration: "once"
      }

      if coupon.percentage?
        stripe_params[:percent_off] = coupon.amount
      else
        stripe_params[:amount_off] = coupon.amount
        stripe_params[:currency] = coupon.currency || PaymentConstants::Currency::USD
      end

      stripe_params[:max_redemptions] = coupon.max_usage if coupon.max_usage.to_i.positive?
      stripe_params[:redeem_by] = coupon.expires_at.to_i if coupon.expires_at.present?

      begin
        stripe_coupon = Stripe::Coupon.create(stripe_params)
        coupon.update_column(:stripe_coupon_id, stripe_coupon.id)
        stripe_coupon.id
      rescue Stripe::InvalidRequestError => e
        if e.message.include?("already exists")
          coupon.update_column(:stripe_coupon_id, coupon.code)
          coupon.code
        else
          Rails.logger.error("#{LOG_PREFIX} Failed to create Stripe coupon: #{e.message}")
          nil
        end
      rescue => e
        Rails.logger.error("#{LOG_PREFIX} Error syncing Stripe coupon: #{e.message}")
        nil
      end
    end
  end
end
