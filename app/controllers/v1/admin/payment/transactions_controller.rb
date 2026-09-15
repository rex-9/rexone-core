class V1::Admin::Payment::TransactionsController < V1::ApplicationController
  # GET /v1/admin/payment/transactions
  def index
    filters = filter_params
    transactions = ::Payment::Transaction.includes(:user, :product)
    transactions = transactions.where(status: filters[:status]) if filters[:status].present?
    transactions = transactions.where(currency: filters[:currency]) if filters[:currency].present?
    transactions = transactions.where(product_id: filters[:product_id]) if filters[:product_id].present?
    transactions = transactions.where(user_id: filters[:user_id]) if filters[:user_id].present?
    transactions = search(transactions, search_term: filters[:search])
    transactions = sort(
      transactions,
      columns: SortConstants::Columns::TRANSACTION,
      default_column: "created_at"
    )
    pagy, records = pagy(:offset, transactions, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::TRANSACTIONS_FETCHED),
      data: ::Payment::TransactionSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/payment/transactions/:id
  def show
    transaction = ::Payment::Transaction.includes(:user, :product).find(params.permit(:id)[:id])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::TRANSACTION_FETCHED),
      data: ::Payment::TransactionSerializer.new(transaction).serializable_hash[:data]
    )
  end

  private

  def filter_params
    params.permit(:status, :currency, :product_id, :user_id, :search, :limit, :page)
  end

  def search(scope, search_term: nil)
    return scope if search_term.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term.strip)}%"
    scope.left_joins(:user, :product).where(
      "users.email ILIKE :term OR users.username ILIKE :term OR payment_products.name ILIKE :term " \
      "OR payment_transactions.stripe_payment_intent_id ILIKE :term OR payment_transactions.stripe_charge_id ILIKE :term",
      term: term
    )
  end

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end
end
