# app/controllers/v1/payment/payments_controller.rb
class V1::Payment::PaymentsController < V1::ApplicationController
  # POST /payment/session
  def create
    product = Payment::Product.active.find(payment_params[:product_id])

    # Check if user already has active subscription
    if product.recurring? && current_user.subscriptions.active.exists?(product_id: product.id)
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::ALREADY_SUBSCRIBED),
        error: payment_message(MessageService::Payment::ACTIVE_SUBSCRIPTION_EXISTS)
      )
      return
    end

    coupon = nil
    validation = nil
    if payment_params[:coupon_code].present?
      validation = CouponService.validate(
        user: current_user,
        product: product,
        code: payment_params[:coupon_code]
      )

      unless validation[:valid]
        render_json_response(
          status_code: 422,
          message: payment_message(MessageService::Payment::COUPON_INVALID),
          error: payment_message(validation[:error])
        )
        return
      end

      coupon = validation[:coupon]
    end

    # Direct access provision for free products or 100% discounted one-time products (bypassing Stripe).
    # Recurring products with coupons proceed to Stripe Checkout so payment details are collected for renewals.
    if product.free? || (product.one_time? && coupon.present? && validation[:final_amount].to_i.zero?)
      if AccessService.has_access?(user_id: current_user.id, product_id: product.id)
        render_json_response(
          status_code: 422,
          message: payment_message(MessageService::Payment::ALREADY_SUBSCRIBED),
          error: payment_message(MessageService::Payment::ACTIVE_ACCESS_EXISTS)
        )
        return
      end

      access = AccessService.grant(
        user_id: current_user.id,
        product_id: product.id
      )

      response_data = {
        free_access_granted: true,
        product_id: product.id,
        access_id: access.id
      }

      if coupon.present?
        transaction = Payment::Transaction.create!(
          user: current_user,
          product: product,
          unit_amount: product.unit_amount,
          amount_received: 0,
          amount_capturable: 0,
          currency: product.currency,
          status: PaymentConstants::TransactionStatus::SUCCEEDED,
          stripe_payment_intent_id: "free_coupon_#{SecureRandom.hex(12)}",
          paid_at: Time.current
        )

        CouponService.apply_to_checkout!(
          user: current_user,
          product: product,
          coupon: coupon,
          purchase_id: transaction.id,
          purchase_type: :trx
        )

        response_data[:coupon_code] = coupon.code
        response_data[:discount_amount] = validation[:discount_amount]
      end

      render_json_response(
        status_code: 200,
        message: payment_message(MessageService::Payment::FREE_ACCESS_GRANTED),
        data: response_data
      )
      return
    end

    checkout_kwargs = {
      user_id: current_user.id,
      product_id: product.id,
      success_url: payment_params[:success_url],
      cancel_url: payment_params[:cancel_url]
    }
    checkout_kwargs[:coupon] = coupon if coupon.present?

    result = PaymentService::Client.create_checkout_session(**checkout_kwargs)

    if result[:error]
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::CHECKOUT_CREATE_FAILED),
        error: result[:error]
      )
    else
      render_json_response(
        status_code: 200,
        message: payment_message(MessageService::Payment::CHECKOUT_CREATED),
        data: {
          checkout_url: result[:checkout_url],
          session_id: result[:session_id]
        }
      )
    end
  end

  # GET /payment/session/:session_id
  def read_status
    result = PaymentService::Client.get_session(status_params[:session_id])

    if result[:error]
      render_json_response(
        status_code: 404,
        message: payment_message(MessageService::Payment::SESSION_NOT_FOUND),
        error: result[:error]
      )
    else
      render_json_response(
        status_code: 200,
        message: payment_message(MessageService::Payment::SESSION_STATUS),
        data: result
      )
    end
  end

  private

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end

  def payment_params
    params.permit(:product_id, :success_url, :cancel_url, :coupon_code)
  end

  def status_params
    params.permit(:session_id)
  end
end
