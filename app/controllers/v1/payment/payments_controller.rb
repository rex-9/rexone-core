# app/controllers/v1/payment/payments_controller.rb
class V1::Payment::PaymentsController < V1::ApplicationController
  # POST /payment/session
  def create
    product = Payment::Product.active.find(payment_params[:product_id])

    # Direct access provision for free products without Stripe redirect
    if product.free?
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

      render_json_response(
        status_code: 200,
        message: payment_message(MessageService::Payment::FREE_ACCESS_GRANTED),
        data: {
          free_access_granted: true,
          product_id: product.id,
          access_id: access.id
        }
      )
      return
    end

    # Check if user already has active subscription
    if product.recurring? && current_user.subscriptions.active.exists?(product_id: product.id)
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::ALREADY_SUBSCRIBED),
        error: payment_message(MessageService::Payment::ACTIVE_SUBSCRIPTION_EXISTS)
      )
      return
    end

    result = PaymentService::Client.create_checkout_session(
      user_id: current_user.id,
      product_id: product.id,
      success_url: payment_params[:success_url],
      cancel_url: payment_params[:cancel_url],
    )

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
    result = PaymentService::Client.get_session(params[:session_id])

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
    params.permit(:product_id, :success_url, :cancel_url)
  end
end
