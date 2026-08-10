# app/services/payment_service/stripe.rb
require "stripe"

module PaymentService
  class Stripe < Base
    Stripe = ::Stripe

    def initialize
      Stripe.api_key = AppConfig::STRIPE_SECRET_KEY
      Stripe.max_network_retries = 2
      Stripe.log_level = "info" if Rails.env.development?
      @webhook_secret = AppConfig::STRIPE_WEBHOOK_SECRET
    end


    # ===== SESSION =====
    def create_checkout_session(user_id:, product_id:, success_url: nil, cancel_url: nil)
      with_stripe_error("Create Checkout Session") do
        user = User.find(user_id)
        product = Payment::Product.find(product_id)

        session = Stripe::Checkout::Session.create(
          customer: user.stripe_customer,
          line_items: [ {
            price: product.stripe_price_id,
            quantity: 1
          } ],
          mode: product.recurring? ? "subscription" : "payment",
          success_url: success_url || AppConfig::STRIPE_SUCCESS_URL,
          cancel_url: cancel_url || AppConfig::STRIPE_CANCEL_URL,
          metadata: {
            user_id: user.id,
            product_id: product.id
          },
          # billing_address_collection: "required", # ask for adress
          # allow_promotion_codes: true, # promo codes
        )

        { checkout_url: session.url, session_id: session.id }
      end
    end

    def get_session(session_id)
      with_stripe_error("Get Session") do
        session = Stripe::Checkout::Session.retrieve(session_id)
        { status: session.status, payment_status: session.payment_status }
      end
    end

    # ===== SUBSCRIPTION =====
    def cancel_subscription(subscription_id)
      with_stripe_error("Cancel Subscription") do
        subscription = Stripe::Subscription.update(
          subscription_id,
          cancel_at_period_end: true
        )
        { subscription_id: subscription.id, status: subscription.status }
      end
    end

    def resume_subscription(subscription_id)
      with_stripe_error("Resume Subscription") do
        subscription = Stripe::Subscription.update(
          subscription_id,
          pause_collection: nil
        )
        { subscription_id: subscription.id, status: subscription.status }
      end
    end

    # ===== REFUND =====
    # def refund_payment(payment_intent_id, amount: nil)
    #   with_stripe_error("Refund Payment") do
    #     params = { payment_intent: payment_intent_id }
    #     params[:amount] = amount if amount.present? # Partial refund

    #     refund = Stripe::Refund.create(params)
    #     { refund_id: refund.id, status: refund.status }
    #   end
    # end

    # ===== WEBHOOK =====
    def handle_webhook(payload, signature)
      event = Stripe::Webhook.construct_event(payload, signature, @webhook_secret)

      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "customer.subscription.created"
        handle_subscription_created(event.data.object)
      when "customer.subscription.updated"
        handle_subscription_updated(event.data.object)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event.data.object)
      when "customer.subscription.paused"
        handle_subscription_paused(event.data.object)
      when "customer.subscription.resumed"
        handle_subscription_resumed(event.data.object)
      # when "charge.refunded"
      #   handle_refund(event.data.object)

      # ===== PRODUCT EVENTS =====
      when "product.created"
        handle_product_created(event.data.object)
      when "product.updated"
        handle_product_updated(event.data.object)
      when "product.deleted"
        handle_product_deleted(event.data.object)
      when "price.created"
        handle_price_created(event.data.object)
      when "price.updated"
        handle_price_updated(event.data.object)
      when "price.deleted"
        handle_price_deleted(event.data.object)
      end

      { status: 200, event: event.type }
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("[Stripe] Webhook signature error: #{e.message}")
      { status: 400, error: "Invalid signature" }
    rescue => e
      Rails.logger.error("[Stripe] Webhook error: #{e.message}")
      { status: 500, error: e.message }
    end

    private

    # === Helpers ===

    def extract_payment_method_info(payment_method_id)
      return { type: "other", details: {} } if payment_method_id.blank?

      begin
        pm = Stripe::PaymentMethod.retrieve(payment_method_id)
        {
          type: pm.type || "other",
          details: {
            brand: pm.card&.brand,
            last4: pm.card&.last4,
            exp_month: pm.card&.exp_month,
            exp_year: pm.card&.exp_year,
            country: pm.card&.country,
            type: pm.type
          }.compact
        }
      rescue => e
        Rails.logger.warn("[Stripe] Could not retrieve payment method #{payment_method_id}: #{e.message}")
        { type: "other", details: {} }
      end
    end

    def extract_payment_method_from_intent(payment_intent_id)
      return { type: "other", details: {} } if payment_intent_id.blank?

      begin
        pi = Stripe::PaymentIntent.retrieve(payment_intent_id)
        return { type: "other", details: {} } if pi.payment_method.blank?

        extract_payment_method_info(pi.payment_method)
      rescue => e
        Rails.logger.warn("[Stripe] Could not retrieve payment intent #{payment_intent_id}: #{e.message}")
        { type: "other", details: {} }
      end
    end

    def with_stripe_error(action, &block)
      yield
    rescue Stripe::StripeError => e
      Rails.logger.error("[Stripe] #{action} error: #{e.message}")
      { error: e.message }
    end

    # === Webhooks ===

    def handle_product_created(product)
      Rails.logger.info("[Stripe] Product created: #{product.id}")
      # Product created event doesn't have price details
      # We'll wait for price.created event to create the full record
    end

    def handle_product_updated(product)
      Rails.logger.info("[Stripe] Product updated: #{product.id}")
      # Update or create the product in our DB
      sync_product(product)
    end

    def sync_product(product)
      # If we have a default_price from Stripe, try to sync it too
      if product.default_price.present?
        begin
          price = Stripe::Price.retrieve(product.default_price)
          sync_price(price)
        rescue => e
          Rails.logger.warn("[Stripe] Could not sync default price: #{e.message}")
        end
      end
    end

    def sync_price(price)
      # Find or initialize by both product_id and price_id
      record = Payment::Product.find_or_initialize_by(
        stripe_product_id: price.product,
        stripe_price_id: price.id
      )

      # Get product details if not provided
      stripe_product = Stripe::Product.retrieve(price.product)

      record.assign_attributes(
        name: stripe_product&.name || "Product #{price.product}",
        description: stripe_product&.description,
        price_unit_amount: price.unit_amount,
        currency: price.currency,
        cycle: price.recurring&.interval,
        active: stripe_product&.active
      )

      if record.save
        Rails.logger.info("[Stripe] Price synced: #{price.id} for product #{price.product}")
      else
        Rails.logger.error("[Stripe] Price sync failed: #{record.errors.full_messages}")
      end
    end

    def handle_price_created(price)
      Rails.logger.info("[Stripe] Price created: #{price.id}")
      sync_price(price)
    end

    def handle_price_updated(price)
      Rails.logger.info("[Stripe] Price updated: #{price.id}")
      sync_price(price)
    end

    def handle_product_deleted(product)
      record = Payment::Product.find_by(stripe_product_id: product.id)
      return unless record

      record.update(active: false)
      Rails.logger.info("[Stripe] Product deleted: #{product.id}")
    end

    def handle_price_deleted(price)
      record = Payment::Product.find_by(stripe_price_id: price.id)
      return unless record

      record.update(
        stripe_price_id: nil,
        active: false
      )
      Rails.logger.info("[Stripe] Price deleted: #{price.id}")
    end

    def handle_checkout_completed(session)
      user_id = session.metadata.user_id
      product_id = session.metadata.product_id
      product = Payment::Product.find(product_id)
      user = User.find(user_id)

      if session.mode == "subscription"
        stripe_sub = Stripe::Subscription.retrieve(session.subscription)

        # Get payment method ID and details
        payment_info = extract_payment_method_info(stripe_sub.default_payment_method)

        # Create db subscription
        subscription = Payment::Subscription.create!(
          user_id: user_id,
          product_id: product_id,
          stripe_subscription_id: session.subscription,
          status: "active",
          cycle: product.cycle,
          started_at: Time.current,
          next_billing_at: Time.current + product.cycle_in_duration,
          payment_method_id: stripe_sub.default_payment_method,
          payment_method_type: payment_info[:type],
          payment_method_details: payment_info[:details]
        )

        # Grant access
        AccessService.grant(
          user_id: user_id,
          product_id: product_id,
          expires_at: product.cycle_in_duration.from_now
        )

        # Notify for subscription created
        NotificationService.subscription_created(
          user, product, subscription
        )

      else
        # One-time purchase - get payment method from payment intent
        payment_method_id = nil
        payment_info = { type: "other", details: {} }

        if session.payment_intent.present?
          begin
            pi = Stripe::PaymentIntent.retrieve(session.payment_intent)
            payment_method_id = pi.payment_method
            payment_info = extract_payment_method_info(payment_method_id) if payment_method_id.present?
          rescue => e
            Rails.logger.warn("[Stripe] Could not retrieve payment intent: #{e.message}")
          end
        end

        transaction = Payment::Transaction.create!(
          user_id: user_id,
          product_id: product_id,
          stripe_payment_intent: session.payment_intent,
          price_unit_amount: product.price_unit_amount,
          currency: product.currency,
          status: "paid",
          paid_at: Time.current,
          payment_method_id: payment_method_id,
          payment_method_type: payment_info[:type],
          payment_method_details: payment_info[:details]
        )

        # Grant lifetime access
        AccessService.grant(
          user_id: user_id,
          product_id: product_id,
          expires_at: nil
        )

        # Notify for one time purchase
        NotificationService.payment_success(
          user, product, transaction
        )
      end
    end

    def handle_subscription_created(subscription)
      record = Payment::Subscription.find_or_initialize_by(stripe_subscription_id: subscription.id)
      record.update(
        status: subscription.status,
        next_billing_at: Time.at(subscription.current_period_end),
        started_at: Time.at(subscription.created),
      )
      # No email needed - checkout.completed already sent confirmation
    end

    def handle_subscription_updated(subscription)
      record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      return unless record

      old_status = record.status

      record.update(
        status: subscription.status,
        next_billing_at: Time.at(subscription.current_period_end),
        ended_at: subscription.ended_at ? Time.at(subscription.ended_at) : nil,
        canceled_at: subscription.canceled_at ? Time.at(subscription.canceled_at) : nil,
      )

      # Send email on status changes
      if old_status != subscription.status
        case subscription.status
        when "past_due"
          # Notify for payment failure
          NotificationService.payment_failed(
            record.user, record.product, record
          )
        end
      end
    end

    def handle_subscription_deleted(subscription)
      record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      return unless record

      record.update(
        status: "canceled",
        canceled_at: subscription.canceled_at ? Time.at(subscription.canceled_at) : Time.current,
        ended_at: subscription.ended_at ? Time.at(subscription.ended_at) : Time.current
      )

      if subscription.canceled_at.present? || subscription.canceled?
        AccessService.revoke(
          user_id: record.user_id,
          product_id: record.product_id
        )
      end
    end

    def handle_subscription_paused(subscription)
      # When the free trial ends...
      # record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      # return unless record
    end

    def handle_subscription_resumed(subscription)
      # Not sure... Lol...
      # record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      # return unless record
    end

    # def handle_refund(charge)
    #   transaction = Payment::Transaction.find_by(stripe_payment_intent: charge.payment_intent)
    #   return unless transaction

    #   transaction.update(
    #     status: "refunded",
    #     refunded_at: Time.at(charge.created)
    #   )

    #   # Revoke access if fully refunded
    #   if charge.refunded
    #     AccessService.revoke(
    #       user_id: transaction.user_id,
    #       product_id: transaction.product_id
    #     )

    #     # Send refund confirmation email
    #     user = transaction.user
    #     product = transaction.product
    #     send_refund_confirmation_email(user, product, transaction)
    #   end
    # end

    # ===== EMAIL NOTIFICATIONS =====

    # Template Example on Onesignal dashboard
    #     <h1>Welcome aboard, {{user_name}}! 🎉</h1>
    # <p>Your subscription to <strong>{{product_name}}</strong> has been confirmed and is now active.</p>
    # <table style="border-collapse: collapse; width: 100%; max-width: 400px; margin: 20px 0;">
    #   <tr>
    #     <td style="padding: 8px 0;"><strong>Start Date:</strong></td>
    #     <td style="padding: 8px 0;">{{start_date}}</td>
    #   </tr>
    #   <tr>
    #     <td style="padding: 8px 0;"><strong>Next Billing:</strong></td>
    #     <td style="padding: 8px 0;">{{next_billing}}</td>
    #   </tr>
    #   <tr>
    #     <td style="padding: 8px 0;"><strong>Plan:</strong></td>
    #     <td style="padding: 8px 0;">{{period}}</td>
    #   </tr>
    # </table>
    # <p>You now have full access. Log in to get started!</p>
    # <p>Thank you for your trust! 🙏</p>
    # <p><strong>Rex9</strong></p>

    # def send_refund_confirmation_email(user, product, transaction)
    #   EmailService::Client.send_template(
    #     to: user.email,
    #     template_id: "payment_refund_confirmation",
    #     template_data: {
    #       user_name: user.name || user.username,
    #       product_name: product.name,
    #       amount: product.display_price,
    #       refunded_on: transaction.refunded_at.strftime("%B %d, %Y")
    #     }
    #   )
    # rescue => e
    #   Rails.logger.error("[Email] Failed to send refund confirmation: #{e.message}")
    # end
  end
end
