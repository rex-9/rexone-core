# app/controllers/v1/payment/subscriptions_controller.rb
class V1::Payment::SubscriptionsController < V1::ApplicationController
  # GET /payment/subscriptions?page=1&limit=10
  def index
    subscriptions = current_user.subscriptions.includes(:product).order(SortConstants::Columns::PRODUCT.first => SortConstants::Order::DESC)
    pagy, records = pagy(:offset, subscriptions, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::SUBSCRIPTIONS_FETCHED),
      data: Payment::SubscriptionSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /payment/subscriptions/:id
  def show
    subscription = current_user.subscriptions.find(params[:id])
    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::SUBSCRIPTION_FETCHED),
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
        message: payment_message(MessageService::Payment::CANNOT_CANCEL),
        error: payment_message(MessageService::Payment::ALREADY_SCHEDULED_FOR_CANCELLATION)
      )
      return
    end

    unless subscription.cancelable?
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::CANNOT_CANCEL),
        error: payment_message(MessageService::Payment::NOT_CANCELABLE)
      )
      return
    end

    result = PaymentService::Client.cancel_subscription(
      subscription.stripe_subscription_id
    )

    if result[:error]
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::CANCEL_FAILED),
        error: result[:error]
      )
      return
    end

    sync_cancellation_state!(subscription, result)

    NotificationService::Center.subscription_canceled(
      subscription.user,
      subscription.product,
      subscription
    )

    active_until = subscription.current_period_end
    msg_key = active_until.present? ?
      MessageService::Payment::SUBSCRIPTION_CANCELED_BODY_WITH_DATE :
      MessageService::Payment::SUBSCRIPTION_CANCELED_BODY

    render_json_response(
      status_code: 200,
      message: payment_message(
        msg_key,
        product_name: subscription.product.name,
        active_until: active_until&.strftime("%B %d, %Y")
      ),
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
        message: payment_message(MessageService::Payment::CANNOT_RESUME),
        error: payment_message(MessageService::Payment::NOT_SCHEDULED_FOR_CANCELLATION)
      )
      return
    end

    result = PaymentService::Client.resume_subscription(
      subscription.stripe_subscription_id
    )

    if result[:error]
      render_json_response(
        status_code: 422,
        message: payment_message(MessageService::Payment::RESUME_FAILED),
        error: result[:error]
      )
      return
    end

    sync_cancellation_state!(subscription, result)

    NotificationService::Center.subscription_resumed(
      subscription.user,
      subscription.product,
      subscription
    )

    render_json_response(
      status_code: 200,
      message: payment_message(
        MessageService::Payment::SUBSCRIPTION_RESUMED_BODY,
        product_name: subscription.product.name
      ),
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
        message: payment_message(MessageService::Payment::CANNOT_REMOVE),
        error: payment_message(MessageService::Payment::ONLY_ENDED_CAN_BE_REMOVED)
      )

      return
    end

    subscription.discard!

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::REMOVED)
    )
  end

  private

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end

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
