# app/services/payment_service/stripe.rb
require "stripe"

module PaymentService
  class Stripe < Base
    def initialize
      @webhook_secret = AppConfig::STRIPE_WEBHOOK_SECRET
    end

    Stripe = ::Stripe

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
    def get_subscription(subscription_id)
      with_stripe_error("Get Subscription") do
        subscription = Stripe::Subscription.retrieve(subscription_id)
        { status: subscription.status, current_period_end: subscription.current_period_end }
      end
    end

    def cancel_subscription(subscription_id)
      with_stripe_error("Cancel Subscription") do
        subscription = Stripe::Subscription.update(
          subscription_id,
          cancel_at_period_end: true
        )
        { subscription_id: subscription.id, status: subscription.status }
      end
    end

    def pause_subscription(subscription_id)
      with_stripe_error("Pause Subscription") do
        subscription = Stripe::Subscription.update(
          subscription_id,
          pause_collection: { behavior: "void" }
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
    def refund_payment(payment_intent_id, amount: nil)
      with_stripe_error("Refund Payment") do
        params = { payment_intent: payment_intent_id }
        params[:amount] = amount if amount.present? # Partial refund

        refund = Stripe::Refund.create(params)
        { refund_id: refund.id, status: refund.status }
      end
    end

    # ===== PRODUCT =====
    def create_product(name:, description:, price_unit_amount:, currency:, cycle: nil)
      with_stripe_error("Create Product") do
        product = Stripe::Product.create(
          name: name,
          description: description,
        )

        price_params = {
          product: product.id,
          unit_amount: price_unit_amount,
          currency: currency
        }

        if cycle.present?
          price_params[:recurring] = { cycle: cycle }
        end

        price = Stripe::Price.create(price_params)

        {
          product_id: product.id,
          price_id: price.id,
          product: product,
          price: price
        }
      end
    end

    def update_product(product_id:, name: nil, description: nil, active: nil)
      with_stripe_error("Update Product") do
        params = {}
        params[:name] = name if name.present?
        params[:description] = description if description.present?
        params[:active] = active unless active.nil?

        product = Stripe::Product.update(product_id, params)
        { product_id: product.id, active: product.active }
      end
    end

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
      when "invoice.payment_succeeded"
        handle_invoice_paid(event.data.object)
      when "invoice.payment_failed"
        handle_invoice_failed(event.data.object)
      when "charge.refunded"
        handle_refund(event.data.object)
      when "charge.dispute.created"
        handle_dispute_created(event.data.object)

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
        stripe_sub = ::Stripe::Subscription.retrieve(session.subscription)

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

        # Send email - subscription confirmation
        send_subscription_confirmation_email(user, product, subscription)

      else
        # One-time purchase - get payment method from payment intent
        payment_method_id = nil
        payment_info = { type: "other", details: {} }

        if session.payment_intent.present?
          begin
            pi = ::Stripe::PaymentIntent.retrieve(session.payment_intent)
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

        # Send email - purchase confirmation
        send_purchase_confirmation_email(user, product, transaction)
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
        when "canceled"
          send_subscription_canceled_email(record.user, record.product, record)
        when "past_due"
          send_payment_failed_email(record.user, record.product, record)
        when "active"
          # If it was canceled and becomes active again (resume)
          if old_status == "canceled"
            send_subscription_renewal_email(record.user, record.product, record)
          end
        end
      end
    end

    def handle_subscription_deleted(subscription)
      record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      return unless record

      user = record.user
      product = record.product

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

        # Send email - subscription canceled
        send_subscription_canceled_email(user, product, record)
      end
    end

    def handle_subscription_paused(subscription)
      record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      return unless record
      record.pause!
      # Optional: Send pause confirmation email
    end

    def handle_subscription_resumed(subscription)
      record = Payment::Subscription.find_by(stripe_subscription_id: subscription.id)
      return unless record
      record.resume!
      # Optional: Send resume confirmation email
    end

    def handle_invoice_paid(invoice)
      subscription = Payment::Subscription.find_by(stripe_subscription_id: invoice.subscription)
      return unless subscription

      user = subscription.user
      product = subscription.product

      # Extend access
      AccessService.grant(
        user_id: subscription.user_id,
        product_id: product.id,
        expires_at: product.cycle_in_duration.from_now
      )

      subscription.update(next_billing_at: Time.at(invoice.period_end))

      # Send email - renewal success
      send_subscription_renewal_email(user, product, subscription)
    end

    def handle_invoice_failed(invoice)
      subscription = Payment::Subscription.find_by(stripe_subscription_id: invoice.subscription)
      return unless subscription

      user = subscription.user
      product = subscription.product

      subscription.update(status: "past_due")

      # Send email - payment failed
      send_payment_failed_email(user, product, subscription)
    end

    def handle_refund(charge)
      transaction = Payment::Transaction.find_by(stripe_payment_intent: charge.payment_intent)
      return unless transaction

      transaction.update(
        status: "refunded",
        refunded_at: Time.at(charge.created)
      )

      # Revoke access if fully refunded
      if charge.refunded
        AccessService.revoke(
          user_id: transaction.user_id,
          product_id: transaction.product_id
        )

        # Send refund confirmation email
        user = transaction.user
        product = transaction.product
        send_refund_confirmation_email(user, product, transaction)
      end
    end

    def handle_dispute_created(dispute)
      transaction = Payment::Transaction.find_by(stripe_payment_intent: dispute.payment_intent)
      return unless transaction

      transaction.update(status: "disputed")

      # Notify admin (you could also email user)
      # AdminNotificationService.send_dispute_alert(transaction)
    end

    # ===== EMAIL NOTIFICATIONS =====

    def send_subscription_confirmation_email(user, product, subscription)
      EmailService::Client.send_template(
        to: user.email,
        template_id: "payment_subscription_confirmation",  # Onesignal template key
        template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          start_date: subscription.started_at.strftime("%B %d, %Y"),
          next_billing: subscription.next_billing_at.strftime("%B %d, %Y"),
          period: product.period_label
        }
      )
    rescue => e
      Rails.logger.error("[Email] Failed to send subscription confirmation: #{e.message}")
    end

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
    # <p><strong>The Meritbox Team</strong></p>

    def send_purchase_confirmation_email(user, product, transaction)
      EmailService::Client.send_template(
        to: user.email,
        template_id: "payment_purchase_confirmation",
        template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          amount: product.display_price,
          date: transaction.paid_at.strftime("%B %d, %Y")
        }
      )
    rescue => e
      Rails.logger.error("[Email] Failed to send purchase confirmation: #{e.message}")
    end

    def send_subscription_canceled_email(user, product, subscription)
      EmailService::Client.send_template(
        to: user.email,
        template_id: "payment_subscription_canceled",
        template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          canceled_on: subscription.canceled_at&.strftime("%B %d, %Y") || "Today",
          valid_until: subscription.ended_at&.strftime("%B %d, %Y") || "End of period"
        }
      )
    rescue => e
      Rails.logger.error("[Email] Failed to send subscription canceled: #{e.message}")
    end

    def send_subscription_renewal_email(user, product, subscription)
      EmailService::Client.send_template(
        to: user.email,
        template_id: "payment_subscription_renewal",
        template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          next_billing: subscription.next_billing_at.strftime("%B %d, %Y")
        }
      )
    rescue => e
      Rails.logger.error("[Email] Failed to send renewal: #{e.message}")
    end

    def send_payment_failed_email(user, product, subscription)
      EmailService::Client.send_template(
        to: user.email,
        template_id: "payment_failed",
        template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          due_date: subscription.next_billing_at.strftime("%B %d, %Y")
        }
      )
    rescue => e
      Rails.logger.error("[Email] Failed to send payment failed: #{e.message}")
    end

    def send_refund_confirmation_email(user, product, transaction)
      EmailService::Client.send_template(
        to: user.email,
        template_id: "payment_refund_confirmation",
        template_data: {
          user_name: user.name || user.username,
          product_name: product.name,
          amount: product.display_price,
          refunded_on: transaction.refunded_at.strftime("%B %d, %Y")
        }
      )
    rescue => e
      Rails.logger.error("[Email] Failed to send refund confirmation: #{e.message}")
    end
  end
end
