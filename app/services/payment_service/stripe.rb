# app/services/payment_service/stripe.rb
require "stripe"

module PaymentService
  class Stripe < Base
    Stripe = ::Stripe
    STRIPE_LOG_PREFIX = "[Stripe]".freeze
    SUPPORTED_WEBHOOK_EVENT_TYPES = PaymentConstants::StripeEvent::ALL

    def initialize
      Stripe.api_key = AppConfig::STRIPE_SECRET_KEY
      Stripe.max_network_retries = 2
      Stripe.log_level = "info" if Rails.env.development?
      @webhook_secret = AppConfig::STRIPE_WEBHOOK_SECRET
    end

    # ===== CUSTOMER =====
    def create_customer(user_id: nil, user: nil)
      with_stripe_error("Create Customer") do
        user ||= User.find(user_id)
        return { customer_id: user.stripe_customer_id } if user.stripe_customer_id.present?

        customer = Stripe::Customer.create(
          email: user.email,
          metadata: { user_id: user.id }
        )
        user.update!(stripe_customer_id: customer.id)
        { customer_id: customer.id }
      end
    end

    # ===== SESSION =====
    def create_checkout_session(user_id:, product_id:, success_url: nil, cancel_url: nil)
      with_stripe_error("Create Checkout Session") do
        user = User.find(user_id)
        product = Payment::Product.find(product_id)

        checkout_params = {
          customer: user.stripe_customer,
          line_items: [ {
            price: product.stripe_price_id,
            quantity: 1
          } ],
          mode: product.recurring? ? PaymentConstants::StripeMode::SUBSCRIPTION : PaymentConstants::StripeMode::PAYMENT,
          success_url: success_url || AppConfig::STRIPE_SUCCESS_URL,
          cancel_url: cancel_url || AppConfig::STRIPE_CANCEL_URL,
          metadata: {
            user_id: user.id,
            product_id: product.id
          }

          # For Subscription Object metadata
          # subscription_data: {
          #   metadata: {
          #     user_id: user.id,
          #     product_id: product.id
          #   }
          # },

          # For Payment Intent Object metadata
          # payment_intent_data: {
          #   metadata: {
          #     user_id: user.id,
          #     product_id: product.id
          #   }
          # }

          # billing_address_collection: "required", # ask for adress
          # allow_promotion_codes: true, # promo codes
        }

        if product.recurring?
          checkout_params[:subscription_data] = {
            metadata: {
              user_id: user.id,
              product_id: product.id
            }
          }
        else
          checkout_params[:payment_intent_data] = {
            metadata: {
              user_id: user.id,
              product_id: product.id
            }
          }
        end

        session = Stripe::Checkout::Session.create(checkout_params)

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

        subscription_cancellation_state(subscription)
      end
    end

    def resume_subscription(subscription_id)
      with_stripe_error("Resume Subscription") do
        subscription = Stripe::Subscription.update(
          subscription_id,
          cancel_at_period_end: false
        )

        subscription_cancellation_state(subscription)
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

    def supported_webhook_event?(event_type)
      SUPPORTED_WEBHOOK_EVENT_TYPES.include?(event_type)
    end

    # Verifies that the webhook came from Stripe and returns a Stripe::Event.
    # This must run synchronously while the original signature is available.
    def verify_webhook(payload, signature)
      Stripe::Webhook.construct_event(
        payload,
        signature,
        @webhook_secret
      )
    end

    # Processes an event that has already passed signature verification.
    #
    # It accepts either:
    # - a Stripe::Event from the webhook controller; or
    # - a Hash loaded from Payment::WebhookEvent#payload by a background job.
    #
    # Do not rescue processing errors here. Solid Queue needs raised exceptions
    # so it can retry failed jobs.
    def process_webhook(event)
      event = normalize_webhook_event(event)

      case event.type
      when PaymentConstants::StripeEvent::CHECKOUT_SESSION_COMPLETED
        handle_checkout_completed(event.data.object)
      when PaymentConstants::StripeEvent::SUBSCRIPTION_UPDATED
        handle_subscription_updated(event.data.object)
      when PaymentConstants::StripeEvent::SUBSCRIPTION_DELETED
        handle_subscription_deleted(event.data.object)
      when PaymentConstants::StripeEvent::SUBSCRIPTION_PAUSED
        handle_subscription_updated(event.data.object)
      when PaymentConstants::StripeEvent::SUBSCRIPTION_RESUMED
        handle_subscription_updated(event.data.object)
      when PaymentConstants::StripeEvent::PRODUCT_UPDATED
        handle_product_updated(event.data.object)
      when PaymentConstants::StripeEvent::PRODUCT_DELETED
        handle_product_deleted(event.data.object)
      when PaymentConstants::StripeEvent::PRICE_CREATED
        handle_price_created(event.data.object)
      when PaymentConstants::StripeEvent::PRICE_UPDATED
        handle_price_updated(event.data.object)
      when PaymentConstants::StripeEvent::PRICE_DELETED
        handle_price_deleted(event.data.object)
      else
        Rails.logger.info(
          "#{STRIPE_LOG_PREFIX} Ignored unsupported webhook event: #{event.type}"
        )
      end

      {
        status: 200,
        event_id: event.id,
        event_type: event.type
      }
    end

    private

    # === Helpers ===

    def normalize_webhook_event(event)
      return event if event.is_a?(Stripe::Event)

      unless event.is_a?(Hash)
        raise PaymentService::Error,
              "Webhook event must be a Stripe::Event or Hash"
      end

      Stripe::Webhook.construct_event_without_verification(
        JSON.generate(event)
      )
    end

    def extract_payment_method_info(payment_method_id)
      return { type: PaymentConstants::StripeStatus::OTHER, details: {} } if payment_method_id.blank?

      begin
        pm = Stripe::PaymentMethod.retrieve(payment_method_id)
        {
          type: pm.type || PaymentConstants::StripeStatus::OTHER,
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
        Rails.logger.warn("#{STRIPE_LOG_PREFIX} Could not retrieve payment method #{payment_method_id}: #{e.message}")
        { type: PaymentConstants::StripeStatus::OTHER, details: {} }
      end
    end

    def with_stripe_error(action, &block)
      yield
    rescue Stripe::StripeError => e
      Rails.logger.error("#{STRIPE_LOG_PREFIX} #{action} error: #{e.message}")
      { error: e.message }
    end

    def stripe_time(timestamp)
      return nil if timestamp.blank?

      Time.at(timestamp).utc
    end

    def subscription_period(subscription)
      subscription_item = subscription.items&.data&.first

      period_start_timestamp =
        subscription[:current_period_start] ||
        subscription_item&.current_period_start

      period_end_timestamp =
        subscription[:current_period_end] ||
        subscription_item&.current_period_end

      if period_start_timestamp.blank? || period_end_timestamp.blank?
        raise PaymentService::Error,
              "Stripe subscription #{subscription.id} has no billing period"
      end

      {
        starts_at: stripe_time(period_start_timestamp),
        ends_at: stripe_time(period_end_timestamp)
      }
    end

    def subscription_started_at(subscription)
      stripe_time(
        subscription[:start_date] ||
        subscription[:created]
      )
    end

    def subscription_cancellation_state(subscription)
      {
        subscription_id: subscription.id,
        status: subscription.status,
        cancel_at_period_end: subscription.cancel_at_period_end,
        cancel_at: stripe_time(subscription.cancel_at),
        canceled_at: stripe_time(subscription.canceled_at),
        ended_at: stripe_time(subscription.ended_at)
      }
    end

    def current_subscription(stripe_subscription)
      Stripe::Subscription.retrieve(stripe_subscription.id)
    end

    def sync_subscription(stripe_subscription)
      subscription = Payment::Subscription.find_or_initialize_by(
        stripe_subscription_id: stripe_subscription.id
      )
      previous_status = subscription.status
      period = subscription_period(stripe_subscription)

      subscription.update!(
        stripe_customer_id: stripe_subscription.customer,
        status: stripe_subscription.status,
        started_at: subscription_started_at(stripe_subscription),
        current_period_start: period[:starts_at],
        current_period_end: period[:ends_at],
        cancel_at_period_end: stripe_subscription.cancel_at_period_end,
        cancel_at: stripe_time(stripe_subscription.cancel_at),
        ended_at: stripe_time(stripe_subscription.ended_at),
        canceled_at: stripe_time(stripe_subscription.canceled_at),
        metadata: stripe_subscription.metadata&.to_h || {}
      )

      if %w[active trialing].include?(subscription.status)
        AccessService.grant(
          user_id: subscription.user_id,
          product_id: subscription.product_id,
          expires_at: period[:ends_at]
        )
      elsif subscription.canceled? || subscription.unpaid? || subscription.paused?
        AccessService.revoke(
          user_id: subscription.user_id,
          product_id: subscription.product_id
        )
      end

      if previous_status.present? &&
          previous_status != PaymentConstants::StripeStatus::PAST_DUE &&
          subscription.past_due?
        NotificationService.payment_failed(
          subscription.user,
          subscription.product,
          subscription
        )
      end

      subscription
    end

    def sync_product(product)
      # If we have a default_price from Stripe, try to sync it too
      if product.default_price.present?
        begin
          price = Stripe::Price.retrieve(product.default_price)
          sync_price(price)
        rescue => e
          Rails.logger.warn("#{STRIPE_LOG_PREFIX} Could not sync default price: #{e.message}")
        end
      end
    end

    def sync_price(price)
      # Find or initialize by both product_id and price_id
      record = Payment::Product.find_or_initialize_by(
        stripe_product_id: price.product
      )

        # Get product details if not provided
        stripe_product = Stripe::Product.retrieve(price.product)

      record.assign_attributes(
        stripe_price_id: price.id,
        name: stripe_product&.name || "Product #{price.product}",
        description: stripe_product&.description,
        price_unit_amount: price.unit_amount,
        currency: price.currency,
        cycle: price.recurring&.interval,
        active: stripe_product&.active && price.active
      )

      if record.save
        Rails.logger.info("#{STRIPE_LOG_PREFIX} Price synced: #{price.id} for product #{price.product}")
      else
        Rails.logger.error("#{STRIPE_LOG_PREFIX} Price sync failed: #{record.errors.full_messages}")
      end
    end

    # === Webhooks ===

    def handle_product_updated(product)
      Rails.logger.info("#{STRIPE_LOG_PREFIX} Product updated: #{product.id}")
      # Update or create the product in our DB
      sync_product(product)
    end

    def handle_price_created(price)
      Rails.logger.info("#{STRIPE_LOG_PREFIX} Price created: #{price.id}")
      sync_price(price)
    end

    def handle_price_updated(price)
      Rails.logger.info("#{STRIPE_LOG_PREFIX} Price updated: #{price.id}")
      sync_price(price)
    end

    def handle_product_deleted(product)
      record = Payment::Product.find_by(stripe_product_id: product.id)
      return unless record

      record.update!(active: false)

      Rails.logger.info("#{STRIPE_LOG_PREFIX} Product deleted: #{product.id}")
    end

    def handle_price_deleted(price)
      record = Payment::Product.find_by(stripe_price_id: price.id)
      return unless record

      record.update!(active: false)

      Rails.logger.info("#{STRIPE_LOG_PREFIX} Price deleted: #{price.id}")
    end

    def handle_checkout_completed(session)
      user_id = session.metadata.user_id
      product_id = session.metadata.product_id
      product = Payment::Product.find(product_id)
      user = User.find(user_id)

      if session.mode == PaymentConstants::StripeMode::SUBSCRIPTION
        stripe_sub = Stripe::Subscription.retrieve(
          session.subscription
        )

        period = subscription_period(stripe_sub)

        payment_method_id = stripe_sub.default_payment_method

        # An expanded Stripe payment method is an object; otherwise it is an ID.
        payment_method_id =
          payment_method_id.id if payment_method_id.respond_to?(:id)

        payment_info = extract_payment_method_info(payment_method_id)

        subscription = Payment::Subscription.find_or_initialize_by(
          stripe_subscription_id: stripe_sub.id
        )
        new_subscription = subscription.new_record?

        subscription.assign_attributes(
          user_id: user_id,
          product_id: product_id,
          stripe_customer_id: stripe_sub.customer,
          status: stripe_sub.status,
          cycle: product.cycle,
          started_at: subscription_started_at(stripe_sub),
          current_period_start: period[:starts_at],
          current_period_end: period[:ends_at],
          cancel_at_period_end: stripe_sub.cancel_at_period_end,
          cancel_at: stripe_time(stripe_sub.cancel_at),
          ended_at: stripe_time(stripe_sub.ended_at),
          canceled_at: stripe_time(stripe_sub.canceled_at),
          payment_method_id: payment_method_id,
          payment_method_type: payment_info[:type],
          payment_method_details: payment_info[:details],
          metadata: stripe_sub.metadata&.to_h || {}
        )

        subscription.save!

        AccessService.grant(
          user_id: user_id,
          product_id: product_id,
          expires_at: period[:ends_at]
        )

        if new_subscription
          NotificationService.subscription_created(
            user,
            product,
            subscription
          )
        end

      else
        # NOTE: For some reason one-time payment not being paid
        unless session.payment_status == PaymentConstants::StripeStatus::PAID
          Rails.logger.warn(
            "#{STRIPE_LOG_PREFIX} Ignored unpaid completed Checkout Session: #{session.id}"
          )
          return
        end

        # One-time purchase - sync with Payment Intent
        payment_intent_id = session.payment_intent

        # Get full payment intent details
        pi = Stripe::PaymentIntent.retrieve(payment_intent_id)

        # Get payment method details
        payment_info = extract_payment_method_info(pi.payment_method)

        # Create or update transaction from Payment Intent
        transaction = Payment::Transaction.find_or_initialize_by(
          stripe_payment_intent_id: payment_intent_id
        )
        new_transaction = transaction.new_record?

        transaction.assign_attributes(
          user_id: user_id,
          product_id: product_id,
          price_unit_amount: pi.amount,
          currency: pi.currency,
          status: pi.status,
          stripe_charge_id: pi.latest_charge,
          stripe_customer_id: pi.customer,
          client_secret: pi.client_secret,
          amount_received: pi.amount_received,
          amount_capturable: pi.amount_capturable,
          paid_at: pi.amount_received > 0 ? Time.at(pi.created) : nil,
          payment_method_id: pi.payment_method,
          payment_method_type: payment_info[:type],
          payment_method_details: payment_info[:details],
          metadata: pi.metadata
        )

        transaction.save!

        if transaction.succeeded?
          AccessService.grant(
            user_id: user_id,
            product_id: product_id,
            expires_at: nil  # Lifetime
          )

          if new_transaction
            NotificationService.payment_success(
              user, product, transaction
            )
          end
        end
      end
    end

    def handle_subscription_updated(stripe_subscription)
      sync_subscription(current_subscription(stripe_subscription))
    end

    def handle_subscription_deleted(stripe_subscription)
      subscription = sync_subscription(stripe_subscription)

      subscription.update!(
        status: PaymentConstants::StripeStatus::CANCELED,
        canceled_at: subscription.canceled_at || Time.current,
        ended_at: subscription.ended_at || Time.current
      )
    end
  end
end
