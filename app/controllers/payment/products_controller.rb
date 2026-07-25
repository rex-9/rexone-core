class Payment::ProductsController < ApplicationController
  # GET /payment/products
  def index
    products = Payment::Product.active.order(created_at: :desc)

    render_json_response(
      status_code: 200,
      message: "Products fetched successfully.",
      data: {
        products: Payment::ProductSerializer.new(products).serializable_hash[:data]
      }
    )
  end

  # GET /payment/products/:id
  def show
    product = Payment::Product.find(params[:id])

    render_json_response(
      status_code: 200,
      message: "Product fetched successfully.",
      data: {
        product: Payment::ProductSerializer.new(product).serializable_hash[:data][:attributes]
      }
    )
  end
end
