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

    # ===== SESSION =====
    def create_checkout_session(user_id:, product_id:, success_url: nil, cancel_url: nil)
      with_stripe_error("Create Checkout Session") do
        user = User.find(user_id)
        product = Payment::Product.find(product_id)
        raise PaymentService::Error, "Free products do not use Stripe checkout" if product.free?

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

    # ===== PRODUCTS =====
    def create_product(attributes)
      with_stripe_error("Create Product") do
        attributes = normalize_product_attributes(attributes)
        stripe_product = nil
        stripe_price = nil

        stripe_product = Stripe::Product.create(
          name: attributes.fetch(:name),
          description: attributes[:description],
          active: attributes.fetch(:active, true),
          metadata: {}
        )

        stripe_price = Stripe::Price.create(
          stripe_price_params(stripe_product.id, attributes)
        )

        Stripe::Product.update(stripe_product.id, default_price: stripe_price.id)

        persist_product(stripe_product, stripe_price, attributes)
      rescue ActiveRecord::ActiveRecordError
        discard_stripe_records(stripe_product&.id, stripe_price&.id)
        raise
      end
    end

    def update_product(product_id, attributes)
      with_stripe_error("Update Product") do
        product = Payment::Product.with_discarded.find(product_id)
        attributes = product_update_attributes(product, attributes)
        previous_stripe_product_attributes = {
          name: product.name,
          description: product.description,
          active: product.active
        }

        Stripe::Product.update(
          product.stripe_product_id,
          name: attributes.fetch(:name),
          description: attributes[:description],
          active: attributes[:active]
        )

        unless price_changed?(product, attributes)
          begin
            product.update!(attributes)
          rescue ActiveRecord::ActiveRecordError
            Stripe::Product.update(product.stripe_product_id, previous_stripe_product_attributes)
            raise
          end
          return product
        end

        old_stripe_price_id = product.stripe_price_id
        stripe_price = Stripe::Price.create(
          stripe_price_params(product.stripe_product_id, attributes)
        )

        Stripe::Product.update(product.stripe_product_id, default_price: stripe_price.id)
        Stripe::Price.update(old_stripe_price_id, active: false)
        begin
          product.update!(attributes.merge(stripe_price_id: stripe_price.id))
        rescue ActiveRecord::ActiveRecordError
          Stripe::Product.update(
            product.stripe_product_id,
            previous_stripe_product_attributes.merge(default_price: old_stripe_price_id)
          )
          Stripe::Price.update(old_stripe_price_id, active: true)
          Stripe::Price.update(stripe_price.id, active: false)
          raise
        end
        product
      end
    end

    def discard_product(product_id)
      with_stripe_error("Discard Product") do
        product = Payment::Product.with_discarded.find(product_id)

        discard_stripe_records(product.stripe_product_id, product.stripe_price_id)
        product.update!(active: false)
        product.discard
        product
      end
    end

    def undiscard_product(product_id)
      with_stripe_error("Undiscard Product") do
        product = Payment::Product.with_discarded.find(product_id)

        Stripe::Product.update(product.stripe_product_id, active: true)
        Stripe::Price.update(product.stripe_price_id, active: true)
        product.update!(active: true)
        product.undiscard
        product
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
      when PaymentConstants::StripeEvent::PRODUCT_CREATED,
           PaymentConstants::StripeEvent::PRODUCT_UPDATED
        handle_product_updated(event.data.object)
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

    def persist_product(stripe_product, stripe_price, attributes)
      product = Payment::Product.find_or_initialize_by(stripe_product_id: stripe_product.id)
      product.update!(product_attributes(stripe_product, stripe_price, attributes))
      product
    end

    def product_attributes(stripe_product, stripe_price, attributes)
      {
        stripe_product_id: stripe_product.id,
        stripe_price_id: stripe_price.id,
        name: attributes.fetch(:name),
        description: attributes[:description],
        price_unit_amount: attributes.fetch(:price_unit_amount),
        currency: attributes.fetch(:currency),
        cycle: attributes[:cycle],
        active: attributes.fetch(:active, true)
      }
    end

    def discard_stripe_records(stripe_product_id, stripe_price_id)
      Stripe::Product.update(stripe_product_id, active: false) if stripe_product_id.present?
      Stripe::Price.update(stripe_price_id, active: false) if stripe_price_id.present?
    end

    def stripe_price_params(stripe_product_id, attributes)
      params = {
        product: stripe_product_id,
        unit_amount: attributes.fetch(:price_unit_amount),
        currency: attributes.fetch(:currency)
      }

      cycle = stripe_cycle_interval(attributes[:cycle])
      params[:recurring] = { interval: cycle } if cycle.present?
      params
    end

    def price_changed?(product, attributes)
      (
        attributes.key?(:price_unit_amount) &&
          attributes[:price_unit_amount] != product.price_unit_amount
      ) ||
        (attributes.key?(:currency) && attributes[:currency] != product.currency) ||
        (
          attributes.key?(:cycle) &&
            stripe_cycle_interval(attributes[:cycle]) != stripe_cycle_interval(product.cycle)
        )
    end

    def product_update_attributes(product, attributes)
      normalize_product_attributes(
        price_unit_amount: attributes.fetch(:price_unit_amount, product.price_unit_amount),
        currency: attributes.fetch(:currency, product.currency),
        cycle: attributes.fetch(:cycle, product.cycle),
        name: attributes.fetch(:name, product.name),
        description: attributes.key?(:description) ? attributes[:description] : product.description,
        active: attributes.key?(:active) ? attributes[:active] : product.active
      )
    end

    def normalize_product_attributes(attributes)
      attributes = attributes.dup
      attributes[:price_unit_amount] = attributes[:price_unit_amount].to_i
      attributes[:cycle] = normalized_product_cycle(attributes[:price_unit_amount], attributes[:cycle])
      attributes
    end

    def normalized_product_cycle(price_unit_amount, cycle)
      price_unit_amount.to_i.zero? ? nil : cycle.presence
    end

    def stripe_cycle_interval(cycle)
      return nil if cycle.blank?

      Payment::Product.cycles.fetch(cycle.to_s, cycle.to_s)
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
      stripe_product = Stripe::Product.retrieve(price.product)
      record = Payment::Product.with_discarded.find_or_initialize_by(
        stripe_product_id: price.product
      )
      inactive_in_stripe = !stripe_product&.active || !price.active

      record.assign_attributes(
        stripe_price_id: price.id,
        name: stripe_product&.name || "Product #{price.product}",
        description: stripe_product&.description,
        price_unit_amount: price.unit_amount,
        currency: price.currency,
        cycle: normalized_product_cycle(price.unit_amount, price.recurring&.interval),
        active: record.discarded? ? false : !inactive_in_stripe
      )

      if record.save
        record.discard if inactive_in_stripe && !record.discarded?
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

    # def handle_refund(charge)
    #   transaction = Payment::Transaction.find_by(stripe_payment_intent_id: charge.payment_intent)
    #   return unless transaction

    #   transaction.update(
    #     status: ::StripeStatus::REFUNDED,
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
