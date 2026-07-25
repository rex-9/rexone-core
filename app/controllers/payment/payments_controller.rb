# app/controllers/payment/payments_controller.rb
class Payment::PaymentsController < ApplicationController
  before_action :authenticate_user!

  # POST /payment/session
  def create
    product = Payment::Product.find(params[:product_id])

    result = PaymentService::Client.create_checkout_session(
      user_id: current_user.id,
      product_id: product.id,
      success_url: params[:success_url],
      cancel_url: params[:cancel_url],
    )

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to create checkout session",
        error: result[:error]
      )
    else
      render_json_response(
        status_code: 200,
        message: "Checkout Session created",
        data: {
          checkout_url: result[:checkout_url],
          session_id: result[:session_id]
        }
      )
    end
  end

  # GET /payment/session/:session_id
  def status
    result = PaymentService::Client.get_session(params[:session_id])

    if result[:error]
      render_json_response(
        status_code: 404,
        message: "Session not found",
        error: result[:error]
      )
    else
      render_json_response(
        status_code: 200,
        message: "Session status",
        data: result
      )
    end
  end

  def cancel_subscription
    subscription = current_user.subscriptions.find(params[:id])

    result = PaymentService::Client.cancel_subscription(subscription.stripe_subscription_id)

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to cancel",
        error: result[:error]
      )
    else
      subscription.cancel!
      render_json_response(
        status_code: 200,
        message: "Subscription canceled"
      )
    end
  end
end
