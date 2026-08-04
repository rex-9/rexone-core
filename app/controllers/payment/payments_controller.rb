# app/controllers/payment/payments_controller.rb
class Payment::PaymentsController < ApplicationController
  before_action :authenticate_user!

  # POST /payment/session
  def create
    product = Payment::Product.find(payment_params[:product_id])

    # Check if user already has active subscription
    if product.recurring? && current_user.subscriptions.active.exists?(product_id: product.id)
      render_json_response(
        status_code: 422,
        message: "Already subscribed",
        error: "You already have an active subscription to this product. You can cancel it first."
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
  def read_status
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

  private

  def payment_params
    params.permit(:product_id, :success_url, :cancel_url)
  end
end
