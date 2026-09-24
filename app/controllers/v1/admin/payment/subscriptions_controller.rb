class V1::Admin::Payment::SubscriptionsController < V1::ApplicationController
  # GET /v1/admin/payment/subscriptions
  def index
    filters = filter_params
    subscriptions = ::Payment::Subscription.includes(:user, :product, user_coupon: :coupon)
    subscriptions = subscriptions.where(status: filters[:status]) if filters[:status].present?
    subscriptions = subscriptions.where(interval: filters[:interval]) if filters[:interval].present?
    subscriptions = subscriptions.where(product_id: filters[:product_id]) if filters[:product_id].present?
    subscriptions = subscriptions.where(user_id: filters[:user_id]) if filters[:user_id].present?
    unless filters[:cancel_at_period_end].nil?
      subscriptions = subscriptions.where(cancel_at_period_end: ActiveModel::Type::Boolean.new.cast(filters[:cancel_at_period_end]))
    end
    subscriptions = search(subscriptions, search_term: filters[:search])
    subscriptions = sort(
      subscriptions,
      columns: SortConstants::Columns::SUBSCRIPTION,
      default_column: "created_at"
    )
    pagy, records = pagy(:offset, subscriptions, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::SUBSCRIPTIONS_FETCHED),
      data: ::Payment::SubscriptionSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/payment/subscriptions/:id
  def show
    subscription = ::Payment::Subscription.includes(:user, :product, user_coupon: :coupon).find(params.permit(:id)[:id])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::SUBSCRIPTION_FETCHED),
      data: ::Payment::SubscriptionSerializer.new(subscription).serializable_hash[:data]
    )
  end

  private

  def filter_params
    params.permit(:status, :interval, :product_id, :user_id, :cancel_at_period_end, :search, :limit, :page)
  end

  def search(scope, search_term: nil)
    return scope if search_term.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.strip)}%"
    scope.left_joins(:user, :product).where(
      "users.email ILIKE :term OR users.username ILIKE :term OR payment_products.name ILIKE :term " \
      "OR payment_subscriptions.stripe_subscription_id ILIKE :term",
      term: term
    )
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end
end
