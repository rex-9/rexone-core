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
        purchase = Payment::Purchase.create!(
          user: current_user,
          product: product,
          provider: PaymentConstants::Provider::STRIPE,
          provider_payment_id: "free_coupon_#{SecureRandom.hex(12)}",
          unit_amount: product.unit_amount,
          amount_received: 0,
          amount_capturable: 0,
          currency: product.currency,
          status: PaymentConstants::PurchaseStatus::SUCCEEDED,
          paid_at: Time.current
        )

        CouponService.apply_to_checkout!(
          user: current_user,
          product: product,
          coupon: coupon,
          payment_id: purchase.id,
          payment_type: :purchase
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

    result = Payment::Providers::Client.create_checkout_session(**checkout_kwargs)

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
    result = Payment::Providers::Client.get_session(status_params[:session_id])

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

  # POST /payment/verify
  def create_verify
    product = Payment::Product.active.find(verify_params[:product_id])

    result = Payment::IapService.verify_and_provision(
      user: current_user,
      product: product,
      provider: verify_params[:provider],
      transaction_id: verify_params[:transaction_id],
      purchase_token: verify_params[:purchase_token],
      receipt_data: verify_params[:receipt_data],
      package_name: verify_params[:package_name],
      coupon_code: verify_params[:coupon_code],
      raw_payload: verify_params[:metadata] || {}
    )

    if result[:error]
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::VERIFICATION_FAILED),
        error: result[:error]
      )
    else
      data = {
        verified: true,
        product_id: product.id,
        provider: result[:provider],
        purchase_id: result[:purchase]&.id,
        subscription_id: result[:subscription]&.id,
        access_id: result[:access]&.id,
        expires_at: result[:access]&.expires_at
      }
      data[:coupon_code] = result[:coupon_code] if result[:coupon_code].present?
      data[:discount_amount] = result[:discount_amount] if result[:discount_amount].present?
      data[:final_amount] = result[:final_amount] if result[:final_amount].present?

      render_json_response(
        status_code: 200,
        message: payment_message(MessageService::Payment::VERIFIED_AND_GRANTED),
        data: data
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

  def verify_params
    params.permit(
      :product_id,
      :provider,
      :transaction_id,
      :purchase_token,
      :receipt_data,
      :package_name,
      :coupon_code,
      metadata: {}
    )
  end
end
