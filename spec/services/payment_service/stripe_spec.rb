require "rails_helper"

RSpec.describe PaymentService::Stripe do
  describe "#create_checkout_session" do
    it "creates a Stripe Checkout session for a free product" do
      service = described_class.new
      user = create(:user, stripe_customer_id: "cus_free")
      product = create(:payment_product, price_unit_amount: 0, cycle: nil)
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
      product = create(:payment_product, price_unit_amount: 2_000, cycle: "month")
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
        price_unit_amount: 2_000,
        currency: "usd",
        cycle: "month",
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
        price_unit_amount: 0,
        currency: "usd",
        cycle: "month",
        active: true
      )
      product = result[:data]

      expect(product).to be_persisted
      expect(product).to be_free
      expect(product.display_price).to eq("Free")
      expect(product.cycle).to be_nil
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
          price_unit_amount: 2_000,
          currency: "usd",
          cycle: "month",
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
        price_unit_amount: 1_000,
        currency: "usd",
        cycle: "month"
      )
      new_price = instance_double("Stripe::Price", id: "price_new")

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(new_price)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(
        product.id,
        price_unit_amount: 2_000,
        currency: "usd",
        cycle: "month"
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

    it "does not create or deactivate a price when the incoming cycle matches the existing enum value" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_existing",
        stripe_price_id: "price_old",
        cycle: "month"
      )

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create)
      allow(Stripe::Price).to receive(:update)

      service.update_product(product.id, cycle: "month")

      expect(Stripe::Price).not_to have_received(:create)
      expect(Stripe::Price).not_to have_received(:update)
    end

    it "creates a zero price when converting a paid product to free" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_paid",
        stripe_price_id: "price_paid",
        price_unit_amount: 1_000
      )
      free_price = instance_double("Stripe::Price", id: "price_free")

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(free_price)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(product.id, price_unit_amount: 0)
      updated_product = result[:data]

      expect(updated_product).to be_free
      expect(updated_product.cycle).to be_nil
      expect(updated_product.stripe_product_id).to eq("prod_paid")
      expect(updated_product.stripe_price_id).to eq("price_free")
      expect(Stripe::Price).to have_received(:create).with(
        product: "prod_paid",
        unit_amount: 0,
        currency: "usd"
      )
      expect(Stripe::Product).to have_received(:update).with("prod_paid", hash_including(default_price: "price_free"))
      expect(Stripe::Price).to have_received(:update).with("price_paid", active: false)
    end

    it "creates a paid replacement price when converting a free product to paid" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_free",
        stripe_price_id: "price_free",
        price_unit_amount: 0,
        cycle: nil
      )
      stripe_price = instance_double("Stripe::Price", id: "price_new")

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(stripe_price)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(product.id, price_unit_amount: 2_000, currency: "usd", cycle: "month")
      updated_product = result[:data]

      expect(updated_product).not_to be_free
      expect(product.reload).not_to be_free
      expect(updated_product.stripe_product_id).to eq("prod_free")
      expect(updated_product.stripe_price_id).to eq("price_new")
      expect(Stripe::Price).to have_received(:create).with(
        hash_including(product: "prod_free", unit_amount: 2_000, currency: "usd", recurring: { interval: "month" })
      )
      expect(Stripe::Price).to have_received(:update).with("price_free", active: false)
    end

    it "restores Stripe price state when database product update fails after price replacement" do
      service = described_class.new
      product = create(
        :payment_product,
        name: "Premium",
        stripe_product_id: "prod_existing",
        stripe_price_id: "price_old",
        price_unit_amount: 1_000,
        currency: "usd",
        cycle: "month",
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
          price_unit_amount: 2_000,
          currency: "usd",
          cycle: "month"
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
      expect(product.price_unit_amount).to eq(2_000)
      expect(product.cycle).to eq("monthly")
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
        metadata: {}
      )
      stripe_price = instance_double(
        "Stripe::Price",
        id: "price_archived",
        product: "prod_archived",
        unit_amount: product.price_unit_amount,
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
      expect(product.price_unit_amount).to eq(0)
      expect(product.cycle).to be_nil
      expect(product.period_label).to eq("One-time purchase")
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
end
