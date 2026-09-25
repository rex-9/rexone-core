# app/services/payment_service/stripe.rb
require "stripe"

module PaymentService
  class Stripe < Base
    Stripe = ::Stripe
    STRIPE_LOG_PREFIX = "[Stripe]".freeze
    SUPPORTED_WEBHOOK_EVENT_TYPES = PaymentConstants::StripeEvent::ALL

    def initialize
      Stripe.api_key = AppConfig::STRIPE_SECRET_KEY
      Stripe.api_version = PaymentConstants::StripeApi::VERSION
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
    def create_checkout_session(user_id:, product_id:, success_url: nil, cancel_url: nil, coupon: nil)
      with_stripe_error("Create Checkout Session") do
        user = User.find(user_id)
        product = Payment::Product.find(product_id)

        meta = {
          user_id: user.id,
          product_id: product.id
        }

        checkout_params = {
          customer: user.stripe_customer,
          line_items: [ {
            price: product.stripe_price_id,
            quantity: 1
          } ],
          mode: product.recurring? ? PaymentConstants::StripeMode::SUBSCRIPTION : PaymentConstants::StripeMode::PAYMENT,
          success_url: success_url || AppConfig::STRIPE_SUCCESS_URL,
          cancel_url: cancel_url || AppConfig::STRIPE_CANCEL_URL,
          metadata: meta

          # billing_address_collection: "required", # ask for adress
          # allow_promotion_codes: true, # promo codes
        }

        if coupon.present?
          stripe_coupon_id = CouponService.ensure_stripe_coupon(coupon)
          checkout_params[:discounts] = [ { coupon: stripe_coupon_id } ] if stripe_coupon_id.present?
          meta[:coupon_id] = coupon.id
        end

        if product.recurring?
          checkout_params[:subscription_data] = {
            metadata: meta.dup
          }
        else
          checkout_params[:payment_intent_data] = {
            metadata: meta.dup
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

        preview = Payment::Product.new(
          name: attributes[:name],
          description: attributes[:description],
          unit_amount: attributes[:unit_amount],
          currency: attributes[:currency],
          interval: attributes[:interval],
          active: attributes.fetch(:active, true),
          code: attributes[:code],
          stripe_product_id: "preview_prod_#{SecureRandom.hex(8)}",
          stripe_price_id: "preview_price_#{SecureRandom.hex(8)}"
        )
        unless preview.valid?
          return { error: preview.errors.full_messages.to_sentence }
        end

        product_code = attributes[:code].presence || preview.code
        attributes = attributes.merge(code: product_code)

        stripe_product = nil
        stripe_price = nil

        stripe_product = Stripe::Product.create(
          name: attributes.fetch(:name),
          description: attributes[:description],
          active: attributes.fetch(:active, true),
          metadata: { code: product_code, environment: Rails.env }.compact
        )

        stripe_price = Stripe::Price.create(
          stripe_price_params(stripe_product.id, attributes)
        )

        Stripe::Product.update(stripe_product.id, default_price: stripe_price.id)

        { data: persist_product(stripe_product, stripe_price, attributes) }
      rescue ActiveRecord::ActiveRecordError
        discard_stripe_records(stripe_product&.id, stripe_price&.id)
        raise
      end
    end

    def update_product(product_id, attributes)
      with_stripe_error("Update Product") do
        product = Payment::Product.with_discarded.find(product_id)
        attributes = product_update_attributes(product, attributes)

        if product.free? && attributes[:unit_amount].to_i.positive?
          return { error: "Free products cannot be converted to premium products" }
        end

        if product.premium? && attributes[:unit_amount].to_i.zero?
          return { error: "Premium products cannot be converted to free products" }
        end

        check_product = Payment::Product.with_discarded.find(product_id)
        check_product.assign_attributes(attributes)
        unless check_product.valid?
          return { error: check_product.errors.full_messages.to_sentence }
        end

        previous_stripe_product_attributes = {
          name: product.name,
          description: product.description,
          active: product.active,
          metadata: { code: product.code, environment: Rails.env }.compact
        }

        Stripe::Product.update(
          product.stripe_product_id,
          name: attributes.fetch(:name),
          description: attributes[:description],
          active: attributes[:active],
          metadata: { code: product.code, environment: Rails.env }.compact
        )

        unless price_changed?(product, attributes)
          begin
            product.update!(attributes)
          rescue ActiveRecord::ActiveRecordError
            Stripe::Product.update(product.stripe_product_id, previous_stripe_product_attributes)
            raise
          end
          return { data: product }
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
        { data: product }
      end
    end

    def discard_product(product_id)
      with_stripe_error("Discard Product") do
        product = Payment::Product.with_discarded.find(product_id)

        discard_stripe_records(product.stripe_product_id, product.stripe_price_id)
        product.update!(active: false)
        product.discard
        { data: product }
      end
    end

    def undiscard_product(product_id)
      with_stripe_error("Undiscard Product") do
        product = Payment::Product.with_discarded.find(product_id)

        Stripe::Product.update(product.stripe_product_id, active: true)
        Stripe::Price.update(product.stripe_price_id, active: true)
        product.update!(active: true)
        product.undiscard
        { data: product }
      end
    end

    # ===== COUPONS =====
    def create_coupon(attributes)
      with_stripe_error("Create Coupon") do
        stripe_params = {
          id: attributes[:code].to_s.strip.upcase,
          name: attributes[:title],
          duration: "once"
        }

        if attributes[:coupon_type].to_s == "percentage" || attributes[:coupon_type].to_i == 0
          stripe_params[:percent_off] = attributes[:amount].to_i
        else
          stripe_params[:amount_off] = attributes[:amount].to_i
          stripe_params[:currency] = attributes[:currency] || PaymentConstants::Currency::USD
        end

        stripe_params[:max_redemptions] = attributes[:max_usage].to_i if attributes[:max_usage].to_i.positive?
        stripe_params[:redeem_by] = attributes[:expires_at].to_i if attributes[:expires_at].present?
        if attributes[:metadata].present? && attributes[:metadata].is_a?(Hash)
          stripe_params[:metadata] = attributes[:metadata].stringify_keys.transform_values(&:to_s)
        end

        begin
          stripe_coupon = Stripe::Coupon.create(stripe_params)
          attributes = attributes.merge(stripe_coupon_id: stripe_coupon.id)
        rescue Stripe::InvalidRequestError => e
          if e.message.include?("already exists")
            attributes = attributes.merge(stripe_coupon_id: stripe_params[:id])
          else
            raise
          end
        end

        coupon = Payment::Coupon.new(attributes)
        coupon.save!
        { data: coupon }
      end
    end

    def update_coupon(coupon_id, attributes)
      with_stripe_error("Update Coupon") do
        coupon = Payment::Coupon.with_discarded.find(coupon_id)
        if coupon.stripe_coupon_id.present?
          stripe_update_params = {}
          stripe_update_params[:name] = attributes[:title] if attributes[:title].present?
          if attributes.key?(:metadata) && attributes[:metadata].is_a?(Hash)
            stripe_update_params[:metadata] = attributes[:metadata].stringify_keys.transform_values(&:to_s)
          end

          if stripe_update_params.any?
            begin
              Stripe::Coupon.update(coupon.stripe_coupon_id, stripe_update_params)
            rescue Stripe::StripeError => e
              Rails.logger.warn("#{STRIPE_LOG_PREFIX} Could not update Stripe coupon #{coupon.stripe_coupon_id}: #{e.message}")
            end
          end
        end
        coupon.update!(attributes)
        { data: coupon }
      end
    end

    def discard_coupon(coupon_id)
      with_stripe_error("Discard Coupon") do
        coupon = Payment::Coupon.find(coupon_id)
        # Note: We do NOT delete from Stripe on soft-delete/discard.
        # Stripe permanently burns deleted coupon IDs (preventing restoration).
        # Rexone's local validation automatically blocks redemptions for discarded coupons.
        coupon.discard
        { data: coupon }
      end
    end

    def undiscard_coupon(coupon_id)
      with_stripe_error("Undiscard Coupon") do
        coupon = Payment::Coupon.with_discarded.find(coupon_id)
        # Restore locally; ensure Stripe coupon exists if missing
        CouponService.ensure_stripe_coupon(coupon) if coupon.stripe_coupon_id.blank?
        coupon.undiscard
        { data: coupon }
      end
    end

    def destroy_coupon(coupon_id)
      with_stripe_error("Destroy Coupon") do
        coupon = Payment::Coupon.with_discarded.find(coupon_id)
        coupon.destroy!
        { data: coupon }
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
      when PaymentConstants::StripeEvent::PRICE_CREATED
        handle_price_created(event.data.object)
      when PaymentConstants::StripeEvent::PRICE_UPDATED
        handle_price_updated(event.data.object)
      when PaymentConstants::StripeEvent::PRICE_DELETED
        handle_price_deleted(event.data.object)
      when PaymentConstants::StripeEvent::COUPON_CREATED
        handle_coupon_created(event.data.object)
      when PaymentConstants::StripeEvent::COUPON_UPDATED
        handle_coupon_updated(event.data.object)
      when PaymentConstants::StripeEvent::COUPON_DELETED
        handle_coupon_deleted(event.data.object)
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
      attrs = {
        stripe_product_id: stripe_product.id,
        stripe_price_id: stripe_price.id,
        name: attributes.fetch(:name),
        description: attributes[:description],
        unit_amount: attributes.fetch(:unit_amount),
        currency: attributes.fetch(:currency),
        interval: attributes[:interval],
        active: attributes.fetch(:active, true)
      }
      attrs[:code] = attributes[:code] if attributes[:code].present?
      attrs
    end

    def discard_stripe_records(stripe_product_id, stripe_price_id)
      Stripe::Product.update(stripe_product_id, active: false) if stripe_product_id.present?
      Stripe::Price.update(stripe_price_id, active: false) if stripe_price_id.present?
    end

    def stripe_price_params(stripe_product_id, attributes)
      params = {
        product: stripe_product_id,
        unit_amount: attributes.fetch(:unit_amount),
        currency: attributes.fetch(:currency)
      }

      interval = stripe_billing_interval(attributes[:interval])
      params[:recurring] = { interval: interval } if interval.present?
      params
    end

    def price_changed?(product, attributes)
      (
        attributes.key?(:unit_amount) &&
          attributes[:unit_amount] != product.unit_amount
      ) ||
        (attributes.key?(:currency) && attributes[:currency] != product.currency) ||
        (
          attributes.key?(:interval) &&
            stripe_billing_interval(attributes[:interval]) != stripe_billing_interval(product.interval)
        )
    end

    def product_update_attributes(product, attributes)
      normalize_product_attributes(
        unit_amount: attributes.fetch(:unit_amount, product.unit_amount),
        currency: attributes.fetch(:currency, product.currency),
        interval: attributes.fetch(:interval, product.interval),
        name: attributes.fetch(:name, product.name),
        description: attributes.key?(:description) ? attributes[:description] : product.description,
        active: attributes.key?(:active) ? attributes[:active] : product.active
      )
    end

    def normalize_product_attributes(attributes)
      attributes = attributes.dup
      attributes[:unit_amount] = attributes[:unit_amount].to_i
      attributes[:interval] = normalized_product_interval(attributes[:unit_amount], attributes[:interval])
      attributes
    end

    def normalized_product_interval(unit_amount, interval)
      unit_amount.to_i.zero? ? nil : interval.presence
    end

    def stripe_billing_interval(interval)
      return nil if interval.blank?

      Payment::Product.intervals.fetch(interval.to_s, interval.to_s)
    end

    def stripe_time(timestamp)
      return nil if timestamp.blank?

      Time.at(timestamp).utc
    end

    def stripe_object_id(value)
      value.respond_to?(:id) ? value.id : value
    end

    def subscription_period(subscription)
      subscription_item = subscription_item!(subscription)
      period_start_timestamp = subscription_item.try(:current_period_start) ||
                                subscription.try(:current_period_start)
      period_end_timestamp = subscription_item.try(:current_period_end) ||
                             subscription.try(:current_period_end)

      if period_start_timestamp.blank? || period_end_timestamp.blank?
        recurring = subscription_item.price&.recurring
        interval = recurring&.interval || PaymentConstants::BillingInterval::MONTH
        period_start_timestamp ||= Time.current.to_i
        duration = case interval.to_s
        when PaymentConstants::BillingInterval::DAY then 1.day
        when PaymentConstants::BillingInterval::WEEK then 1.week
        when PaymentConstants::BillingInterval::YEAR then 1.year
        else 1.month
        end
        period_end_timestamp ||= (Time.at(period_start_timestamp).utc + duration).to_i
      end

      {
        starts_at: stripe_time(period_start_timestamp),
        ends_at: stripe_time(period_end_timestamp)
      }
    end

    def subscription_item!(subscription)
      items = subscription.items&.data || []
      return items.first if items.one?

      # NOTE: Can Improve Later for one subscription with multiple products, but better keep one subs one product
      raise PaymentService::Error,
            "Stripe subscription #{subscription.id} must have exactly one subscription item"
    end

    def subscription_item_attributes(subscription)
      item = subscription_item!(subscription)
      price = item.price
      recurring = price&.recurring

      if price.blank? || recurring.blank? || price.unit_amount.nil?
        raise PaymentService::Error,
              "Stripe subscription #{subscription.id} has no fixed recurring price"
      end

      {
        stripe_subscription_item_id: item.id,
        stripe_price_id: price.id,
        currency: subscription.currency || price.currency,
        unit_amount: price.unit_amount,
        quantity: item.quantity || 1,
        interval: recurring.interval,
        interval_count: recurring.interval_count
      }
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
        **subscription_item_attributes(stripe_subscription),
        stripe_customer_id: stripe_object_id(stripe_subscription.customer),
        status: stripe_subscription.status,
        started_at: stripe_time(stripe_subscription.start_date),
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
      elsif subscription.past_due? || subscription.canceled? || subscription.unpaid? || subscription.paused?
        AccessService.revoke(
          user_id: subscription.user_id,
          product_id: subscription.product_id
        )
      end

      if previous_status.present? &&
          previous_status != PaymentConstants::StripeStatus::PAST_DUE &&
          subscription.past_due?
        NotificationService::Center.payment_failed(
          subscription.user,
          subscription.product,
          subscription
        )
      end

      subscription
    end

    def sync_product(product)
      record = Payment::Product.with_discarded.find_by(stripe_product_id: product.id)
      if record
        record.assign_attributes(
          name: product.name.presence || record.name,
          description: product.description,
          active: product.active
        )

        if record.save
          if product.active && record.discarded?
            record.undiscard
          elsif !product.active && !record.discarded?
            record.discard
          end
          Rails.logger.info("#{STRIPE_LOG_PREFIX} Product synced: #{product.id}")
        else
          Rails.logger.error("#{STRIPE_LOG_PREFIX} Product sync failed: #{record.errors.full_messages}")
        end
      end

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
      normalized_currency = price.currency.to_s.downcase
      unless Payment::Product.currencies.key?(normalized_currency)
        Rails.logger.warn(
          "#{STRIPE_LOG_PREFIX} Ignored price sync: Unsupported currency #{price.currency} for price #{price.id}"
        )
        return
      end

      stripe_product = Stripe::Product.retrieve(price.product)
      record = Payment::Product.with_discarded.find_or_initialize_by(
        stripe_product_id: price.product
      )

      if record.persisted? && stripe_product.respond_to?(:default_price) && stripe_product.default_price.present? && stripe_product.default_price != price.id
        Rails.logger.info(
          "#{STRIPE_LOG_PREFIX} Ignored price sync: Price #{price.id} is not default price (#{stripe_product.default_price}) for product #{stripe_product.id}"
        )
        return
      end

      if record.persisted? && record.free? && price.unit_amount.to_i.positive?
        Rails.logger.warn(
          "#{STRIPE_LOG_PREFIX} Ignored price sync: Free product #{record.id} cannot be converted to premium via Stripe price #{price.id}"
        )
        return
      end

      if record.persisted? && record.premium? && price.unit_amount.to_i.zero?
        Rails.logger.warn(
          "#{STRIPE_LOG_PREFIX} Ignored price sync: Premium product #{record.id} cannot be converted to free via Stripe price #{price.id}"
        )
        return
      end

      inactive_in_stripe = !stripe_product&.active || !price.active

      if record.new_record? && stripe_product&.metadata.present?
        metadata_code = stripe_product.metadata[:code] || stripe_product.metadata["code"]
        record.code = metadata_code if metadata_code.present?
      end

      record.assign_attributes(
        stripe_price_id: price.id,
        name: stripe_product&.name.presence || record.name.presence || "Product #{price.product}",
        description: stripe_product&.description,
        unit_amount: price.unit_amount,
        currency: normalized_currency,
        interval: normalized_product_interval(price.unit_amount, price.recurring&.interval),
        active: !inactive_in_stripe
      )

      if record.save
        if inactive_in_stripe && !record.discarded?
          record.discard
        elsif !inactive_in_stripe && record.discarded?
          record.undiscard
        end
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

        payment_method_id = stripe_object_id(stripe_sub.default_payment_method)

        payment_info = extract_payment_method_info(payment_method_id)

        subscription = Payment::Subscription.find_or_initialize_by(
          stripe_subscription_id: stripe_sub.id
        )
        new_subscription = subscription.new_record?

        subscription.assign_attributes(
          **subscription_item_attributes(stripe_sub),
          user_id: user_id,
          product_id: product_id,
          stripe_customer_id: stripe_object_id(stripe_sub.customer),
          status: stripe_sub.status,
          started_at: stripe_time(stripe_sub.start_date),
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

        coupon_id = session.metadata&.coupon_id
        if coupon_id.present?
          coupon = Payment::Coupon.find_by(id: coupon_id)
          if coupon
            CouponService.apply_to_checkout!(
              user: user,
              product: product,
              coupon: coupon,
              purchase_id: subscription.id,
              purchase_type: :sbs
            )
          end
        end

        AccessService.grant(
          user_id: user_id,
          product_id: product_id,
          expires_at: period[:ends_at]
        )

        if new_subscription
          NotificationService::Center.subscription_created(
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
        payment_method_id = stripe_object_id(pi.payment_method)
        payment_info = extract_payment_method_info(payment_method_id)

        # Create or update transaction from Payment Intent
        transaction = Payment::Transaction.find_or_initialize_by(
          stripe_payment_intent_id: payment_intent_id
        )
        new_transaction = transaction.new_record?

        transaction.assign_attributes(
          user_id: user_id,
          product_id: product_id,
          unit_amount: pi.amount,
          currency: pi.currency,
          status: pi.status,
          stripe_charge_id: stripe_object_id(pi.latest_charge),
          stripe_customer_id: stripe_object_id(pi.customer),
          client_secret: pi.client_secret,
          amount_received: pi.amount_received,
          amount_capturable: pi.amount_capturable,
          paid_at: pi.amount_received > 0 ? Time.at(pi.created) : nil,
          payment_method_id: payment_method_id,
          payment_method_type: payment_info[:type],
          payment_method_details: payment_info[:details],
          metadata: pi.metadata&.to_h || {}
        )

        transaction.save!

        coupon_id = session.metadata&.coupon_id
        if coupon_id.present?
          coupon = Payment::Coupon.find_by(id: coupon_id)
          if coupon
            CouponService.apply_to_checkout!(
              user: user,
              product: product,
              coupon: coupon,
              purchase_id: transaction.id,
              purchase_type: :trx
            )
          end
        end

        if transaction.succeeded?
          AccessService.grant(
            user_id: user_id,
            product_id: product_id,
            expires_at: nil  # Lifetime
          )

          if new_transaction
            NotificationService::Center.payment_success(
              user, product, transaction
            )
          end
        end
      end
    end

    def handle_coupon_created(stripe_coupon)
      coupon = Payment::Coupon.with_discarded.find_by(stripe_coupon_id: stripe_coupon.id) ||
               Payment::Coupon.with_discarded.find_by(code: stripe_coupon.id.to_s.strip.upcase)
      if coupon
        coupon.update!(
          stripe_coupon_id: stripe_coupon.id,
          title: stripe_coupon.name.presence || coupon.title,
          active: stripe_coupon.valid,
          metadata: (coupon.metadata || {}).merge(stripe_coupon.metadata&.to_h || {})
        )
        Rails.logger.info("#{STRIPE_LOG_PREFIX} Linked existing coupon from webhook: #{coupon.code} (Stripe ID: #{stripe_coupon.id})")
        return
      end

      c_type = stripe_coupon.percent_off.present? ? :percentage : :fixed
      c_amount = stripe_coupon.percent_off || stripe_coupon.amount_off || 0

      cleaned_code = stripe_coupon.id.to_s.strip.upcase.gsub(/[^A-Z0-9]/, "")
      cleaned_code = cleaned_code.ljust(6, "0") if cleaned_code.length < 6

      coupon = Payment::Coupon.new(
        stripe_coupon_id: stripe_coupon.id,
        title: stripe_coupon.name.presence || stripe_coupon.id,
        code: cleaned_code,
        coupon_type: c_type,
        amount: c_amount,
        currency: stripe_coupon.currency.presence || PaymentConstants::Currency::USD,
        max_usage: stripe_coupon.max_redemptions || 0,
        expires_at: stripe_coupon.redeem_by ? Time.at(stripe_coupon.redeem_by) : nil,
        active: stripe_coupon.valid,
        metadata: stripe_coupon.metadata&.to_h || {}
      )
      coupon.save!
      Rails.logger.info("#{STRIPE_LOG_PREFIX} Coupon created from webhook: #{coupon.code} (Stripe ID: #{stripe_coupon.id})")
    rescue => e
      Rails.logger.error("#{STRIPE_LOG_PREFIX} Failed to handle coupon created webhook: #{e.message}")
    end

    def handle_coupon_updated(stripe_coupon)
      coupon = Payment::Coupon.with_discarded.find_by(stripe_coupon_id: stripe_coupon.id) ||
               Payment::Coupon.with_discarded.find_by(code: stripe_coupon.id.to_s.strip.upcase)
      return unless coupon

      attrs = {
        stripe_coupon_id: stripe_coupon.id,
        title: stripe_coupon.name.presence || coupon.title,
        active: stripe_coupon.valid
      }
      if stripe_coupon.metadata.present?
        attrs[:metadata] = (coupon.metadata || {}).merge(stripe_coupon.metadata.to_h)
      end

      coupon.update!(attrs)
      Rails.logger.info("#{STRIPE_LOG_PREFIX} Coupon updated from webhook: #{coupon.code}")
    rescue => e
      Rails.logger.error("#{STRIPE_LOG_PREFIX} Failed to handle coupon updated webhook: #{e.message}")
    end

    def handle_coupon_deleted(stripe_coupon)
      coupon = Payment::Coupon.with_discarded.find_by(stripe_coupon_id: stripe_coupon.id) ||
               Payment::Coupon.with_discarded.find_by(code: stripe_coupon.id.to_s.strip.upcase)
      return unless coupon

      coupon.destroy!
      Rails.logger.info("#{STRIPE_LOG_PREFIX} Coupon permanently deleted from webhook: #{coupon.code}")
    rescue => e
      Rails.logger.error("#{STRIPE_LOG_PREFIX} Failed to handle coupon deleted webhook: #{e.message}")
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
