# app/controllers/v1/payment/transactions_controller.rb
class V1::Payment::TransactionsController < V1::ApplicationController
  # GET /payment/transactions
  def index
    transactions = current_user.transactions.includes(:product).order(created_at: :desc)

    render_json_response(
      status_code: 200,
      message: "Transactions fetched successfully.",
      data: Payment::TransactionSerializer.new(transactions).serializable_hash[:data]
    )
  end

  # GET /payment/transactions/:id
  def show
    transaction = current_user.transactions.find(params[:id])

    render_json_response(
      status_code: 200,
      message: "Transaction fetched successfully.",
      data: Payment::TransactionSerializer.new(transaction).serializable_hash[:data][:attributes]
    )
  end

  # GET /payment/transactions/recent
  def read_recent
    transactions = current_user.transactions.includes(:product).successful.recent

    render_json_response(
      status_code: 200,
      message: "Recent transactions fetched successfully.",
      data: Payment::TransactionSerializer.new(transactions).serializable_hash[:data]
    )
  end

  private

  def transaction_params
    params.permit(:id)
  end
end
