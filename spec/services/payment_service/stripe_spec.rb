require "rails_helper"

RSpec.describe PaymentService::Stripe do
  describe "Stripe 2026-08-26.dahlia subscription mapping" do
    let(:service) { described_class.new }
    let(:stripe_subscription) do
      Stripe::Subscription.construct_from(
        id: "sub_snapshot",
        object: "subscription",
        customer: "cus_snapshot",
        currency: "usd",
        start_date: 1_788_800_000,
        items: {
          object: "list",
          data: [ {
            id: "si_snapshot",
            object: "subscription_item",
            current_period_start: 1_788_800_000,
            current_period_end: 1_791_478_400,
            quantity: 2,
            price: {
              id: "price_snapshot",
              object: "price",
              currency: "usd",
              unit_amount: 2_500,
              recurring: { interval: "month", interval_count: 1 }
            }
          } ]
        }
      )
    end

    it "reads period and price snapshot fields from the subscription item" do
      expect(Stripe.api_version).to eq(PaymentConstants::StripeApi::VERSION)
      expect(service.send(:subscription_period, stripe_subscription)).to eq(
        starts_at: Time.at(1_788_800_000).utc,
        ends_at: Time.at(1_791_478_400).utc
      )
      expect(service.send(:subscription_item_attributes, stripe_subscription)).to eq(
        stripe_subscription_item_id: "si_snapshot",
        stripe_price_id: "price_snapshot",
        currency: "usd",
        unit_amount: 2_500,
        quantity: 2,
        interval: "month",
        interval_count: 1
      )
    end
  end

  describe "#create_checkout_session" do
    it "creates a Stripe Checkout session for a free product" do
      service = described_class.new
      user = create(:user, stripe_customer_id: "cus_free")
      product = create(:payment_product, unit_amount: 0, interval: nil)
      session = instance_double("Stripe::Checkout::Session", url: "https://checkout.stripe.test/free", id: "cs_free")

      allow(Stripe::Checkout::Session).to receive(:create).and_return(session)

      result = service.create_checkout_session(user_id: user.id, product_id: product.id)

      expect(result).to eq(checkout_url: "https://checkout.stripe.test/free", session_id: "cs_free")
      expect(Stripe::Checkout::Session).to have_received(:create).with(
        hash_including(
          customer: "cus_free",
          line_items: [ hash_including(price: product.stripe_price_id, quantity: 1) ],
          mode: PaymentConstants::StripeMode::PAYMENT
        )
      )
    end

    it "creates a subscription-mode Checkout session for a recurring product" do
      service = described_class.new
      user = create(:user, stripe_customer_id: "cus_sub")
      product = create(:payment_product, unit_amount: 2_000, interval: "month")
      session = instance_double("Stripe::Checkout::Session", url: "https://checkout.stripe.test/sub", id: "cs_sub")
      
      allow(Stripe::Checkout::Session).to receive(:create).and_return(session)
      
      result = service.create_checkout_session(user_id: user.id, product_id: product.id)
      
      expect(result).to eq(checkout_url: "https://checkout.stripe.test/sub", session_id: "cs_sub")
      expect(Stripe::Checkout::Session).to have_received(:create).with(
        hash_including(
          customer: "cus_sub",
          mode: PaymentConstants::StripeMode::SUBSCRIPTION,
          subscription_data: hash_including(metadata: hash_including(user_id: user.id, product_id: product.id))
        )
      )
    end
  end

  describe "#create_product" do
    it "creates Stripe records and persists the local premium product" do
      service = described_class.new
      stripe_product = instance_double("Stripe::Product", id: "prod_new")
      stripe_price = instance_double("Stripe::Price", id: "price_new")

      allow(Stripe::Product).to receive(:create).and_return(stripe_product)
      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(stripe_price)

      result = service.create_product(
        name: "Premium",
        description: "Premium access",
        unit_amount: 2_000,
        currency: "usd",
        interval: "month",
        active: true
      )
      product = result[:data]

      expect(product).to be_persisted
      expect(product).to be_premium
      expect(product.stripe_product_id).to eq("prod_new")
      expect(product.stripe_price_id).to eq("price_new")
      expect(Payment::Product.count).to eq(1)
      expect(Stripe::Product).to have_received(:update).with("prod_new", default_price: "price_new")
    end

    it "creates Stripe records and persists the free product with a zero lifetime price" do
      service = described_class.new
      stripe_product = instance_double("Stripe::Product", id: "prod_free")
      stripe_price = instance_double("Stripe::Price", id: "price_free")

      allow(Stripe::Product).to receive(:create).and_return(stripe_product)
      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(stripe_price)

      result = service.create_product(
        name: "Free",
        description: "Free access",
        unit_amount: 0,
        currency: "usd",
        interval: "month",
        active: true
      )
      product = result[:data]

      expect(product).to be_persisted
      expect(product).to be_free
      expect(product.display_price).to eq("Free")
      expect(product.interval).to be_nil
      expect(product.stripe_product_id).to eq("prod_free")
      expect(product.stripe_price_id).to eq("price_free")
      expect(Stripe::Price).to have_received(:create).with(
        product: "prod_free",
        unit_amount: 0,
        currency: "usd"
      )
      expect(Stripe::Product).to have_received(:update).with("prod_free", default_price: "price_free")
    end

    it "deactivates Stripe records when database product persistence fails" do
      service = described_class.new
      stripe_product = instance_double("Stripe::Product", id: "prod_new")
      stripe_price = instance_double("Stripe::Price", id: "price_new")
      invalid_product = Payment::Product.new

      allow(Stripe::Product).to receive(:create).and_return(stripe_product)
      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(stripe_price)
      allow(Stripe::Price).to receive(:update)
      allow_any_instance_of(Payment::Product).to receive(:update!)
        .and_raise(ActiveRecord::RecordInvalid.new(invalid_product))

      expect do
        service.create_product(
          name: "Premium",
          description: "Premium access",
          unit_amount: 2_000,
          currency: "usd",
          interval: "month",
          active: true
        )
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(Stripe::Product).to have_received(:update).with("prod_new", default_price: "price_new")
      expect(Stripe::Product).to have_received(:update).with("prod_new", active: false)
      expect(Stripe::Price).to have_received(:update).with("price_new", active: false)
    end
  end

  describe "#undiscard_product" do
    it "reactivates the Stripe product and price before restoring the local record" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_discarded",
        stripe_price_id: "price_discarded",
        active: false
      )
      product.discard!

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:update)

      result = service.undiscard_product(product.id)
      restored_product = result[:data]

      expect(restored_product).to be_active
      expect(restored_product).not_to be_discarded
      expect(Stripe::Product).to have_received(:update).with("prod_discarded", active: true)
      expect(Stripe::Price).to have_received(:update).with("price_discarded", active: true)
    end
  end

  describe "#update_product" do
    it "deactivates the previous Stripe price after creating a replacement price" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_existing",
        stripe_price_id: "price_old",
        unit_amount: 1_000,
        currency: "usd",
        interval: "month"
      )
      new_price = instance_double("Stripe::Price", id: "price_new")

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(new_price)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(
        product.id,
        unit_amount: 2_000,
        currency: "usd",
        interval: "month"
      )
      updated_product = result[:data]

      expect(updated_product.stripe_price_id).to eq("price_new")
      expect(product.reload.stripe_price_id).to eq("price_new")
      expect(Stripe::Product).to have_received(:update).with(
        "prod_existing",
        hash_including(default_price: "price_new")
      )
      expect(Stripe::Price).to have_received(:update).with("price_old", active: false)
    end

    it "does not create or deactivate a price when only product fields change" do
      service = described_class.new
      product = create(:payment_product, stripe_product_id: "prod_existing", stripe_price_id: "price_old")

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create)
      allow(Stripe::Price).to receive(:update)

      service.update_product(product.id, name: "Updated product")

      expect(Stripe::Price).not_to have_received(:create)
      expect(Stripe::Price).not_to have_received(:update)
    end

    it "does not create or deactivate a price when the incoming interval matches the existing enum value" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_existing",
        stripe_price_id: "price_old",
        interval: "month"
      )

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create)
      allow(Stripe::Price).to receive(:update)

      service.update_product(product.id, interval: "month")

      expect(Stripe::Price).not_to have_received(:create)
      expect(Stripe::Price).not_to have_received(:update)
    end

    it "rejects converting a paid product to free" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_paid",
        stripe_price_id: "price_paid",
        unit_amount: 1_000
      )

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(product.id, unit_amount: 0)

      expect(result[:error]).to eq("Premium products cannot be converted to free products")
      expect(product.reload).to be_premium
      expect(Stripe::Price).not_to have_received(:create)
    end

    it "rejects converting a free product to paid" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_free",
        stripe_price_id: "price_free",
        unit_amount: 0,
        interval: nil
      )

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(product.id, unit_amount: 2_000, currency: "usd", interval: "month")

      expect(result[:error]).to eq("Free products cannot be converted to premium products")
      expect(product.reload).to be_free
      expect(Stripe::Price).not_to have_received(:create)
    end

    it "restores Stripe price state when database product update fails after price replacement" do
      service = described_class.new
      product = create(
        :payment_product,
        name: "Premium",
        stripe_product_id: "prod_existing",
        stripe_price_id: "price_old",
        unit_amount: 1_000,
        currency: "usd",
        interval: "month",
        active: true
      )
      new_price = instance_double("Stripe::Price", id: "price_new")
      invalid_product = Payment::Product.new

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(new_price)
      allow(Stripe::Price).to receive(:update)
      allow_any_instance_of(Payment::Product).to receive(:update!)
        .and_raise(ActiveRecord::RecordInvalid.new(invalid_product))

      expect do
        service.update_product(
          product.id,
          unit_amount: 2_000,
          currency: "usd",
          interval: "month"
        )
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(Stripe::Product).to have_received(:update).with(
        "prod_existing",
        hash_including(default_price: "price_new")
      )
      expect(Stripe::Product).to have_received(:update).with(
        "prod_existing",
        hash_including(name: "Premium", active: true, default_price: "price_old")
      )
      expect(Stripe::Price).to have_received(:update).with("price_old", active: false)
      expect(Stripe::Price).to have_received(:update).with("price_old", active: true)
      expect(Stripe::Price).to have_received(:update).with("price_new", active: false)
    end
  end

  describe "webhook product sync" do
    it "accepts and dispatches Stripe product update events" do
      service = described_class.new
      event = {
        "id" => "evt_product_updated",
        "object" => "event",
        "type" => PaymentConstants::StripeEvent::PRODUCT_UPDATED,
        "data" => {
          "object" => {
            "id" => "prod_updated",
            "object" => "product"
          }
        }
      }

      allow(service).to receive(:handle_product_updated)

      expect(service).to be_supported_webhook_event(event.fetch("type"))

      service.process_webhook(event)

      expect(service).to have_received(:handle_product_updated).with(
        have_attributes(id: "prod_updated")
      )
    end

    it "creates a database premium product from a Stripe price webhook" do
      service = described_class.new
      stripe_product = instance_double(
        "Stripe::Product",
        id: "prod_webhook_premium",
        name: "Webhook Premium",
        description: "Premium from Stripe",
        active: true,
        default_price: "price_webhook_premium",
        metadata: {}
      )
      stripe_price = instance_double(
        "Stripe::Price",
        id: "price_webhook_premium",
        product: "prod_webhook_premium",
        unit_amount: 2_000,
        currency: "usd",
        recurring: instance_double("Stripe::Recurring", interval: "month"),
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve).with("prod_webhook_premium").and_return(stripe_product)

      service.send(:sync_price, stripe_price)

      product = Payment::Product.find_by!(stripe_product_id: "prod_webhook_premium")
      expect(product).to be_premium
      expect(product.stripe_price_id).to eq("price_webhook_premium")
      expect(product.unit_amount).to eq(2_000)
      expect(product.interval).to eq("month")
    end

    it "discards the local product when Stripe deactivates its product" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_archived",
        stripe_price_id: "price_archived",
        active: true
      )
      stripe_product = instance_double(
        "Stripe::Product",
        id: "prod_archived",
        name: product.name,
        description: product.description,
        active: false,
        default_price: "price_archived",
        metadata: {}
      )
      stripe_price = instance_double(
        "Stripe::Price",
        id: "price_archived",
        product: "prod_archived",
        unit_amount: product.unit_amount,
        currency: product.currency,
        recurring: nil,
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve).with("prod_archived").and_return(stripe_product)

      service.send(:sync_price, stripe_price)

      expect(product.reload).to be_discarded
      expect(product.active).to be(false)
    end

    it "creates a database free lifetime product from a Stripe price webhook" do
      service = described_class.new
      stripe_product = instance_double(
        "Stripe::Product",
        id: "prod_webhook_free",
        name: "Webhook Free",
        description: "Free from Stripe",
        active: true,
        default_price: "price_webhook_free",
        metadata: {}
      )
      stripe_price = instance_double(
        "Stripe::Price",
        id: "price_webhook_free",
        product: "prod_webhook_free",
        unit_amount: 0,
        currency: "usd",
        recurring: instance_double("Stripe::Recurring", interval: "month"),
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve).with("prod_webhook_free").and_return(stripe_product)

      service.send(:sync_price, stripe_price)

      product = Payment::Product.find_by!(stripe_product_id: "prod_webhook_free")
      expect(product).to be_free
      expect(product.stripe_price_id).to eq("price_webhook_free")
      expect(product.unit_amount).to eq(0)
      expect(product.interval).to be_nil
      expect(product.period_label).to eq("One-time purchase")
    end

    it "skips price sync when currency is not supported" do
      service = described_class.new
      stripe_price = instance_double(
        "Stripe::Price",
        id: "price_unsupported",
        product: "prod_unsupported",
        unit_amount: 1_000,
        currency: "eur",
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve)

      service.send(:sync_price, stripe_price)

      expect(Stripe::Product).not_to have_received(:retrieve)
      expect(Payment::Product.find_by(stripe_product_id: "prod_unsupported")).to be_nil
    end

    it "skips price sync when price is not default_price on an existing product" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_multi_price",
        stripe_price_id: "price_default",
        unit_amount: 2_000
      )
      stripe_product = instance_double(
        "Stripe::Product",
        id: "prod_multi_price",
        name: product.name,
        description: product.description,
        default_price: "price_default",
        active: true,
        metadata: {}
      )
      secondary_price = instance_double(
        "Stripe::Price",
        id: "price_secondary",
        product: "prod_multi_price",
        unit_amount: 5_000,
        currency: "usd",
        recurring: instance_double("Stripe::Recurring", interval: "year"),
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve).with("prod_multi_price").and_return(stripe_product)

      service.send(:sync_price, secondary_price)

      expect(product.reload.stripe_price_id).to eq("price_default")
      expect(product.unit_amount).to eq(2_000)
    end

    it "skips price sync when trying to convert an existing premium product to free" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_prem_lock",
        stripe_price_id: "price_prem_lock",
        unit_amount: 2_000
      )
      stripe_product = instance_double(
        "Stripe::Product",
        id: "prod_prem_lock",
        name: product.name,
        description: product.description,
        default_price: "price_prem_to_free",
        active: true,
        metadata: {}
      )
      zero_price = instance_double(
        "Stripe::Price",
        id: "price_prem_to_free",
        product: "prod_prem_lock",
        unit_amount: 0,
        currency: "usd",
        recurring: nil,
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve).with("prod_prem_lock").and_return(stripe_product)

      service.send(:sync_price, zero_price)

      expect(product.reload).to be_premium
      expect(product.stripe_price_id).to eq("price_prem_lock")
      expect(product.unit_amount).to eq(2_000)
    end

    it "undiscards a discarded product when Stripe reactivates product and price" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_reactivate",
        stripe_price_id: "price_reactivate",
        active: false
      )
      product.discard!

      stripe_product = instance_double(
        "Stripe::Product",
        id: "prod_reactivate",
        name: product.name,
        description: product.description,
        default_price: "price_reactivate",
        active: true,
        metadata: {}
      )
      stripe_price = instance_double(
        "Stripe::Price",
        id: "price_reactivate",
        product: "prod_reactivate",
        unit_amount: product.unit_amount,
        currency: product.currency,
        recurring: nil,
        active: true
      )

      allow(Stripe::Product).to receive(:retrieve).with("prod_reactivate").and_return(stripe_product)

      service.send(:sync_price, stripe_price)

      expect(product.reload).not_to be_discarded
      expect(product.active).to be(true)
    end

    it "directly updates product and undiscards via sync_product even if default_price is blank" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_sync_direct",
        name: "Old Name",
        description: "Old Desc",
        active: false
      )
      product.discard!

      stripe_product_obj = instance_double(
        "Stripe::Product",
        id: "prod_sync_direct",
        name: "New Direct Name",
        description: "New Direct Desc",
        active: true,
        default_price: nil
      )

      service.send(:sync_product, stripe_product_obj)

      expect(product.reload).not_to be_discarded
      expect(product.active).to be(true)
      expect(product.name).to eq("New Direct Name")
      expect(product.description).to eq("New Direct Desc")
    end
  end

  describe "#discard_product" do
    it "deactivates Stripe records and discards the local product" do
      service = described_class.new
      product = create(:payment_product, stripe_product_id: "prod_active", stripe_price_id: "price_active")
      
      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:update)
      
      result = service.discard_product(product.id)
      discarded_product = result[:data]
      
      expect(discarded_product).to be_discarded
      expect(discarded_product.active).to be(false)
      expect(Stripe::Product).to have_received(:update).with("prod_active", active: false)
      expect(Stripe::Price).to have_received(:update).with("price_active", active: false)
    end
  end

  describe "#create_customer" do
    it "creates a Stripe customer and persists the customer ID" do
      service = described_class.new
      user = create(:user, stripe_customer_id: nil)
      customer = instance_double("Stripe::Customer", id: "cus_new")
      
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      
      result = service.create_customer(user: user)
      
      expect(result).to eq(customer_id: "cus_new")
      expect(user.reload.stripe_customer_id).to eq("cus_new")
      expect(Stripe::Customer).to have_received(:create).with(hash_including(email: user.email))
    end
    
    it "returns the existing customer ID without calling Stripe" do
      service = described_class.new
      user = create(:user, stripe_customer_id: "cus_existing")
      
      allow(Stripe::Customer).to receive(:create)
      
      result = service.create_customer(user: user)
      
      expect(result).to eq(customer_id: "cus_existing")
      expect(Stripe::Customer).not_to have_received(:create)
    end
  end

  describe "Coupons" do
    let(:service) { described_class.new }

    describe "#create_coupon" do
      it "creates a coupon on Stripe with metadata and persists in database" do
        stripe_coupon = instance_double("Stripe::Coupon", id: "WELCOME20")
        allow(Stripe::Coupon).to receive(:create).and_return(stripe_coupon)

        result = service.create_coupon(
          code: "WELCOME20",
          title: "Welcome 20% Off",
          coupon_type: :percentage,
          amount: 20,
          currency: "usd",
          metadata: { tier: "vip" }
        )

        expect(result[:data]).to be_a(Payment::Coupon)
        expect(result[:data].stripe_coupon_id).to eq("WELCOME20")
        expect(Stripe::Coupon).to have_received(:create).with(
          hash_including(
            id: "WELCOME20",
            name: "Welcome 20% Off",
            percent_off: 20,
            metadata: { "tier" => "vip" }
          )
        )
      end
    end

    describe "#update_coupon" do
      it "updates title and metadata on Stripe when stripe_coupon_id is present" do
        coupon = create(:payment_coupon, stripe_coupon_id: "STRIPE_CPN_1", title: "Old Title")
        allow(Stripe::Coupon).to receive(:update)

        result = service.update_coupon(coupon.id, title: "New Title", metadata: { "env" => "staging" })

        expect(result[:data].reload.title).to eq("New Title")
        expect(Stripe::Coupon).to have_received(:update).with(
          "STRIPE_CPN_1",
          name: "New Title",
          metadata: { "env" => "staging" }
        )
      end
    end

    describe "#destroy_coupon" do
      it "deletes the coupon from Stripe and permanently destroys the local record" do
        coupon = create(:payment_coupon, stripe_coupon_id: "STRIPE_CPN_DEL")
        allow(Stripe::Coupon).to receive(:delete)

        service.destroy_coupon(coupon.id)

        expect(Stripe::Coupon).to have_received(:delete).with("STRIPE_CPN_DEL")
        expect(Payment::Coupon.find_by(id: coupon.id)).to be_nil
      end
    end

    describe "Coupon Webhooks" do
      let(:stripe_coupon_object) do
        OpenStruct.new(
          id: "SUMMER50",
          name: "Summer 50% Off",
          percent_off: 50,
          amount_off: nil,
          currency: "usd",
          max_redemptions: 100,
          redeem_by: 1_790_000_000,
          valid: true,
          metadata: { "channel" => "email" }
        )
      end

      it "creates a new coupon from coupon.created webhook" do
        service.send(:handle_coupon_created, stripe_coupon_object)

        coupon = Payment::Coupon.find_by!(code: "SUMMER50")
        expect(coupon.title).to eq("Summer 50% Off")
        expect(coupon.amount).to eq(50)
        expect(coupon.percentage?).to be(true)
        expect(coupon.metadata).to eq({ "channel" => "email" })
      end

      it "links existing coupon by code on coupon.created webhook without error" do
        existing = create(:payment_coupon, code: "SUMMER50", stripe_coupon_id: nil, title: "Draft Summer")

        service.send(:handle_coupon_created, stripe_coupon_object)

        expect(existing.reload.stripe_coupon_id).to eq("SUMMER50")
        expect(existing.title).to eq("Summer 50% Off")
        expect(existing.metadata).to eq({ "channel" => "email" })
      end

      it "updates coupon from coupon.updated webhook" do
        coupon = create(:payment_coupon, code: "SUMMER50", stripe_coupon_id: "SUMMER50", title: "Old Title")
        updated_obj = OpenStruct.new(
          id: "SUMMER50",
          name: "Updated Summer Title",
          valid: true,
          metadata: { "ref" => "twitter" }
        )

        service.send(:handle_coupon_updated, updated_obj)

        expect(coupon.reload.title).to eq("Updated Summer Title")
        expect(coupon.metadata).to eq({ "ref" => "twitter" })
      end

      it "permanently deletes coupon from coupon.deleted webhook" do
        coupon = create(:payment_coupon, code: "SUMMER50", stripe_coupon_id: "SUMMER50")

        service.send(:handle_coupon_deleted, stripe_coupon_object)

        expect(Payment::Coupon.find_by(id: coupon.id)).to be_nil
      end
    end
  end

  describe "Subscription Webhooks" do
    let(:service) { described_class.new }
    let(:user) { create(:user) }
    let(:product) { create(:payment_product, stripe_product_id: "prod_sub_spec", stripe_price_id: "price_sub_spec") }
    let(:price_double) do
      OpenStruct.new(
        id: "price_sub_spec",
        currency: "usd",
        unit_amount: 1_000,
        recurring: OpenStruct.new(interval: "month", interval_count: 1)
      )
    end
    let(:item_double) do
      OpenStruct.new(
        id: "si_sub_spec",
        price: price_double,
        quantity: 1,
        current_period_start: 1.month.ago.to_i,
        current_period_end: 1.month.from_now.to_i
      )
    end
    let(:stripe_subscription) do
      OpenStruct.new(
        id: "sub_webhook_test",
        customer: "cus_webhook_test",
        status: "past_due",
        start_date: 1.month.ago.to_i,
        currency: "usd",
        cancel_at_period_end: false,
        cancel_at: nil,
        ended_at: nil,
        canceled_at: nil,
        metadata: {},
        items: OpenStruct.new(data: [item_double])
      )
    end

    it "revokes access and dispatches payment_failed notification when status transitions to past_due" do
      subscription = create(
        :payment_subscription,
        stripe_subscription_id: "sub_webhook_test",
        user: user,
        product: product,
        status: "active"
      )
      create(:access, user: user, product: product, status: "active")
      allow(NotificationService::Center).to receive(:payment_failed)

      service.send(:sync_subscription, stripe_subscription)

      expect(AccessService.has_access?(user_id: user.id, product_id: product.id)).to be(false)
      expect(NotificationService::Center).to have_received(:payment_failed).with(
        user,
        product,
        subscription
      )
    end

    it "grants access when subscription status is active" do
      stripe_subscription.status = "active"
      create(
        :payment_subscription,
        stripe_subscription_id: "sub_webhook_test",
        user: user,
        product: product,
        status: "past_due"
      )

      service.send(:sync_subscription, stripe_subscription)

      expect(AccessService.has_access?(user_id: user.id, product_id: product.id)).to be(true)
    end

    it "creates new subscription and grants access for active webhook with metadata" do
      stripe_subscription.id = "sub_brand_new_123"
      stripe_subscription.status = "active"
      stripe_subscription.metadata = { user_id: user.id, product_id: product.id }

      expect do
        service.send(:sync_subscription, stripe_subscription)
      end.to change(Payment::Subscription, :count).by(1)

      expect(AccessService.has_access?(user_id: user.id, product_id: product.id)).to be(true)
    end

    it "resolves user by stripe_customer_id and product by stripe_price_id when metadata is absent" do
      user.update!(stripe_customer_id: "cus_webhook_test")
      product_record = product
      stripe_subscription.id = "sub_fallback_resolution"
      stripe_subscription.status = "active"
      stripe_subscription.metadata = {}

      expect do
        service.send(:sync_subscription, stripe_subscription)
      end.to change(Payment::Subscription, :count).by(1)

      created_sub = Payment::Subscription.find_by(stripe_subscription_id: "sub_fallback_resolution")
      expect(created_sub.user_id).to eq(user.id)
      expect(created_sub.product_id).to eq(product.id)
      expect(AccessService.has_access?(user_id: user.id, product_id: product.id)).to be(true)
    end

    it "returns nil without raising when user or product cannot be found" do
      stripe_subscription.id = "sub_unknown_entities"
      stripe_subscription.customer = "cus_nonexistent"
      stripe_subscription.metadata = { user_id: SecureRandom.uuid, product_id: SecureRandom.uuid }

      result = service.send(:sync_subscription, stripe_subscription)
      expect(result).to be_nil
    end
  end
end
