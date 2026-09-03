# app/controllers/v1/payment/transactions_controller.rb
class V1::Payment::TransactionsController < V1::ApplicationController
  # GET /payment/transactions?page=1&limit=10
  def index
    transactions = current_user.transactions.includes(:product).order(SortConstants::Columns::PRODUCT.first => SortConstants::Order::DESC)
    pagy, records = pagy(:offset, transactions, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::TRANSACTIONS_FETCHED),
      data: Payment::TransactionSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /payment/transactions/:id
  def show
    transaction = current_user.transactions.find(params[:id])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::TRANSACTION_FETCHED),
      data: Payment::TransactionSerializer.new(transaction).serializable_hash[:data][:attributes]
    )
  end

  # GET /payment/transactions/recent?page=1&limit=10
  def read_recent
    transactions = current_user.transactions.includes(:product).successful.recent
    pagy, records = pagy(:offset, transactions, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: payment_message(MessageService::Payment::RECENT_TRANSACTIONS_FETCHED),
      data: Payment::TransactionSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  private

  def payment_message(key, **options)
    MessageService::Payment.t(key, **options)
  end

  def transaction_params
    params.permit(:id)
  end
end
