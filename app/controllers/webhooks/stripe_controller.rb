# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ActionController::API
  def create
    payload = request.body.read
    signature = request.headers["HTTP_STRIPE_SIGNATURE"]

    result = PaymentService::Client.handle_webhook(payload, signature)

    render json: { status: result[:status] || 200 }, status: result[:status] || 200
  end
end
