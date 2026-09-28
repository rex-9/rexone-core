# frozen_string_literal: true

# app/services/payment/providers/client.rb
module Payment
  module Providers
    class Client
      class << self
        delegate :create_customer,
                 :create_checkout_session,
                 :get_session,
                 :cancel_subscription,
                 :resume_subscription,
                 :create_coupon,
                 :update_coupon,
                 :discard_coupon,
                 :undiscard_coupon,
                 :destroy_coupon,
                 to: :stripe_provider

        def create_product(attributes)
          if attributes[:unit_amount].to_i.zero?
            create_local_product(attributes.merge(unit_amount: 0, interval: nil))
          elsif in_app_only_product?(attributes)
            create_local_product(attributes)
          else
            stripe_provider.create_product(attributes)
          end
        end

        def update_product(product_id, attributes)
          product = Payment::Product.with_discarded.find(product_id)
          if product.available_on_stripe?
            stripe_provider.update_product(product_id, attributes)
          else
            update_local_product(product, attributes)
          end
        end

        def discard_product(product_id)
          product = Payment::Product.with_discarded.find(product_id)
          if product.available_on_stripe?
            stripe_provider.discard_product(product_id)
          else
            product.update!(active: false)
            product.discard
            { data: product }
          end
        end

        def undiscard_product(product_id)
          product = Payment::Product.with_discarded.find(product_id)
          if product.available_on_stripe?
            stripe_provider.undiscard_product(product_id)
          else
            product.undiscard
            product.update!(active: true)
            { data: product }
          end
        end

        def verify_purchase(provider: nil, **kwargs)
          provider(provider).verify_purchase(**kwargs)
        end

        def supported_webhook_event?(event_type, provider: nil)
          provider(provider).supported_webhook_event?(event_type)
        end

        def verify_webhook(payload, signature, provider: nil)
          provider(provider).verify_webhook(payload, signature)
        end

        def process_webhook(event, provider: nil)
          provider(provider).process_webhook(event)
        end

        def for_provider(name)
          provider(name)
        end

        def reset_providers!
          @stripe = nil
          @google_play = nil
          @app_store = nil
        end

        private

        def in_app_only_product?(attributes)
          attributes[:stripe_product_id].blank? &&
            attributes[:stripe_price_id].blank? &&
            (attributes[:google_play_product_id].present? || attributes[:app_store_product_id].present?)
        end

        def create_local_product(attributes)
          product = Payment::Product.new(
            name: attributes[:name],
            description: attributes[:description],
            unit_amount: attributes[:unit_amount].to_i,
            currency: attributes[:currency] || PaymentConstants::Currency::USD,
            interval: attributes[:interval],
            active: attributes.fetch(:active, true),
            code: attributes[:code],
            stripe_product_id: attributes[:stripe_product_id],
            stripe_price_id: attributes[:stripe_price_id],
            google_play_product_id: attributes[:google_play_product_id],
            app_store_product_id: attributes[:app_store_product_id]
          )
          if product.save
            { data: product }
          else
            { error: product.errors.full_messages.to_sentence }
          end
        end

        def update_local_product(product, attributes)
          if product.free? && attributes.key?(:unit_amount) && attributes[:unit_amount].to_i.positive?
            return { error: "Free products cannot be converted to premium products" }
          end

          if product.premium? && attributes.key?(:unit_amount) && attributes[:unit_amount].to_i.zero?
            return { error: "Premium products cannot be converted to free products" }
          end

          allowed_attrs = attributes.slice(
            :name, :description, :unit_amount, :currency, :interval, :active,
            :google_play_product_id, :app_store_product_id
          )
          product.assign_attributes(allowed_attrs)
          if product.save
            { data: product }
          else
            { error: product.errors.full_messages.to_sentence }
          end
        end

        def stripe_provider
          @stripe ||= Stripe.new
        end

        def provider(name = nil)
          provider_name = name.presence || default_provider
          case provider_name.to_s.downcase
          when PaymentConstants::Provider::GOOGLE_PLAY
            @google_play ||= GooglePlay.new
          when PaymentConstants::Provider::APP_STORE
            @app_store ||= AppStore.new
          else
            stripe_provider
          end
        end

        def default_provider
          if defined?(AppConfig::PAYMENT_PROVIDER) && AppConfig::PAYMENT_PROVIDER.present?
            AppConfig::PAYMENT_PROVIDER
          else
            PaymentConstants::Provider::STRIPE
          end
        end
      end
    end
  end
end
