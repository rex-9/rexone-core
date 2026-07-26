class Payment::SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  # GET /payment/subscriptions
  def index
    subscriptions = current_user.subscriptions.includes(:product).order(created_at: :desc)
    render_json_response(
      status_code: 200,
      message: "Subscriptions fetched successfully.",
      data: {
        subscriptions: Payment::SubscriptionSerializer.new(subscriptions).serializable_hash[:data]
      }
    )
  end

  # GET /payment/subscriptions/:id
  def show
    subscription = current_user.subscriptions.find(params[:id])
    render_json_response(
      status_code: 200,
      message: "Subscription fetched successfully.",
      data: {
        subscription: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /payment/subscriptions/:id/cancel - Cancel at period end
  def cancel
    subscription = current_user.subscriptions.find(params[:id])

    if subscription.canceled_at.present?
      render_json_response(
        status_code: 422,
        message: "Cannot cancel subscription",
        error: "Subscription is already scheduled for cancellation"
      )
      return
    end

    unless subscription.active?
      render_json_response(
        status_code: 422,
        message: "Cannot cancel subscription",
        error: "Subscription is not active"
      )
      return
    end

    result = PaymentService::Client.cancel_subscription(subscription.stripe_subscription_id)

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to cancel subscription",
        error: result[:error]
      )
      return
    end

    subscription.update(canceled_at: Time.current)

    render_json_response(
      status_code: 200,
      message: "Subscription will be canceled at the end of billing period",
      data: {
        subscription: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /payment/subscriptions/:id/resume - Resume from cancellation
  def resume
    subscription = current_user.subscriptions.find(params[:id])

    unless subscription.scheduled_for_cancellation?
      render_json_response(
        status_code: 422,
        message: "Cannot resume subscription",
        error: "Subscription is not scheduled for cancellation"
      )
      return
    end

    result = PaymentService::Client.resume_subscription(subscription.stripe_subscription_id)

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to resume subscription",
        error: result[:error]
      )
      return
    end

    subscription.update(canceled_at: nil)

    render_json_response(
      status_code: 200,
      message: "Subscription resumed successfully",
      data: {
        subscription: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
      }
    )
  end

  # DELETE /payment/subscriptions/:id - Fully cancel (already ended)
  def destroy
    subscription = current_user.subscriptions.find(params[:id])
    subscription.destroy!
    render_json_response(
      status_code: 200,
      message: "Subscription removed successfully"
    )
  end
end
