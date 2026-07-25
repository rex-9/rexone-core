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

  # DELETE /payment/subscriptions/:id
  def destroy
    subscription = current_user.subscriptions.find(params[:id])

    if subscription.active?
      result = PaymentService::Client.cancel_subscription(subscription.stripe_subscription_id)

      if result[:error]
        render_json_response(
          status_code: 422,
          message: "Failed to cancel subscription",
          error: result[:error]
        )
        return
      end

      subscription.cancel!
    end

    render_json_response(
      status_code: 200,
      message: "Subscription canceled successfully.",
      data: {
        subscription: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /payment/subscriptions/:id/pause
  def pause
    subscription = current_user.subscriptions.find(params[:id])

    unless subscription.active?
      render_json_response(
        status_code: 422,
        message: "Cannot pause inactive subscription",
        error: "Subscription is not active"
      )
      return
    end

    result = PaymentService::Client.pause_subscription(subscription.stripe_subscription_id)

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to pause subscription",
        error: result[:error]
      )
      return
    end

    subscription.pause!

    render_json_response(
      status_code: 200,
      message: "Subscription paused successfully.",
      data: {
        subscription: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /payment/subscriptions/:id/resume
  def resume
    subscription = current_user.subscriptions.find(params[:id])

    unless subscription.paused?
      render_json_response(
        status_code: 422,
        message: "Cannot resume active subscription",
        error: "Subscription is not paused"
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

    subscription.resume!

    render_json_response(
      status_code: 200,
      message: "Subscription resumed successfully.",
      data: {
        subscription: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
      }
    )
  end
end
