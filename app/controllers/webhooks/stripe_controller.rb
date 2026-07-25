# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    signature = request.headers["HTTP_STRIPE_SIGNATURE"]

    result = PaymentService::Client.handle_webhook(payload, signature)

    render json: { status: result[:status] || 200 }, status: result[:status] || 200
  end
end
