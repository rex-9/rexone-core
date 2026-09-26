# frozen_string_literal: true

# app/controllers/v1/payment/coupons_controller.rb
class V1::Payment::CouponsController < V1::ApplicationController
  # POST /v1/payment/coupons/validate
  def validate_coupon
    unless CouponService.allowed?(current_user.id)
      remaining = CouponService.cooldown_remaining(current_user.id)
      render_json_response(
        status_code: 429,
        message: payment_message(MessageService::Payment::COUPON_INVALID),
        error: payment_message(
          MessageService::Payment::TOO_MANY_COUPON_ATTEMPTS_WITH_WAIT,
          seconds: remaining
        ),
        meta: {
          remaining_attempts: 0,
          cooldown_remaining: remaining
        }
      )
      return
    end

    product = Payment::Product.active.find(validate_params[:product_id])

    result = CouponService.validate(
      user: current_user,
      product: product,
      code: validate_params[:code]
    )

    if result[:valid]
      CouponService.record_success(current_user.id)
      coupon = result[:coupon]
      render_json_response(
        status_code: 200,
        message: payment_message(MessageService::Payment::COUPON_VALID),
        data: {
          valid: true,
          coupon: ::Payment::CouponSerializer.record_attributes(coupon),
          original_amount: result[:original_amount],
          discount_amount: result[:discount_amount],
          final_amount: result[:final_amount],
          currency: result[:currency]
        }
      )
    else
      failure_data = CouponService.record_failure(current_user.id)
      is_cooldown = (failure_data[:cooldown_remaining] || 0).positive?

      error_msg = if is_cooldown
        payment_message(
          MessageService::Payment::TOO_MANY_COUPON_ATTEMPTS_WITH_WAIT,
          seconds: failure_data[:cooldown_remaining]
        )
      else
        payment_message(result[:error])
      end

      render_json_response(
        status_code: is_cooldown ? 429 : 422,
        message: payment_message(MessageService::Payment::COUPON_INVALID),
        error: error_msg,
        meta: {
          remaining_attempts: failure_data[:remaining_attempts],
          cooldown_remaining: failure_data[:cooldown_remaining] || 0
        }
      )
    end
  end

  private

  def permission_resource_name
    IamConstants::Resource::PAYMENT_COUPONS
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end

  def validate_params
    params.permit(:code, :product_id)
  end
end
