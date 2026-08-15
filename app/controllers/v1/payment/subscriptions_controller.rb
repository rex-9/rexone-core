# app/controllers/v1/payment/subscriptions_controller.rb
class V1::Payment::SubscriptionsController < V1::ApplicationController
  # GET /payment/subscriptions
  def index
    subscriptions = current_user.subscriptions.includes(:product).order(created_at: :desc)
    render_json_response(
      status_code: 200,
      message: "Subscriptions fetched successfully.",
      data: Payment::SubscriptionSerializer.new(subscriptions).serializable_hash[:data]
    )
  end

  # GET /payment/subscriptions/:id
  def show
    subscription = current_user.subscriptions.find(params[:id])
    render_json_response(
      status_code: 200,
      message: "Subscription fetched successfully.",
      data: Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data][:attributes]
    )
  end

  # POST /payment/subscriptions/:id/cancel
  # Schedule cancellation at the end of the current billing period.
  def create_cancel
    subscription = current_user.subscriptions.find(params[:id])

    if subscription.scheduled_for_cancellation?
      render_json_response(
        status_code: 422,
        message: "Cannot cancel subscription",
        error: "Subscription is already scheduled for cancellation"
      )
      return
    end

    unless subscription.cancelable?
      render_json_response(
        status_code: 422,
        message: "Cannot cancel subscription",
        error: "Subscription cannot be canceled in its current state"
      )
      return
    end

    result = PaymentService::Client.cancel_subscription(
      subscription.stripe_subscription_id
    )

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to cancel subscription",
        error: result[:error]
      )
      return
    end

    sync_cancellation_state!(subscription, result)

    NotificationService.subscription_canceled(
      subscription.user,
      subscription.product,
      subscription
    )

    render_json_response(
      status_code: 200,
      message: "Subscription will be canceled at the end of the billing period",
      data: serialized_subscription(subscription)
    )
  end

  # POST /payment/subscriptions/:id/resume
  # Stop a pending end-of-period cancellation.
  def create_resume
    subscription = current_user.subscriptions.find(params[:id])

    unless subscription.scheduled_for_cancellation?
      render_json_response(
        status_code: 422,
        message: "Cannot resume subscription",
        error: "Subscription is not scheduled for cancellation"
      )
      return
    end

    result = PaymentService::Client.resume_subscription(
      subscription.stripe_subscription_id
    )

    if result[:error]
      render_json_response(
        status_code: 422,
        message: "Failed to resume subscription",
        error: result[:error]
      )
      return
    end

    sync_cancellation_state!(subscription, result)

    NotificationService.subscription_resumed(
      subscription.user,
      subscription.product,
      subscription
    )

    render_json_response(
      status_code: 200,
      message: "Subscription resumed successfully",
      data: serialized_subscription(subscription)
    )
  end

  # DELETE /payment/subscriptions/:id
  # Hide an already-ended subscription from the normal client listing.
  def destroy
    subscription = current_user.subscriptions.find(params[:id])

    unless subscription.ended?
      render_json_response(
        status_code: 422,
        message: "Cannot remove subscription",
        error: "Only an ended subscription can be removed"
      )

      return
    end

    subscription.discard!

    render_json_response(
      status_code: 200,
      message: "Subscription removed successfully"
    )
  end

  private

  def subscription_params
    params.permit(:id)
  end

  def sync_cancellation_state!(subscription, result)
    subscription.update!(
      status: result[:status],
      cancel_at_period_end: result[:cancel_at_period_end],
      cancel_at: result[:cancel_at],
      canceled_at: result[:canceled_at],
      ended_at: result[:ended_at]
    )
  end

  def serialized_subscription(subscription)
    Payment::SubscriptionSerializer
      .new(subscription)
      .serializable_hash
      .dig(:data, :attributes)
  end
end
