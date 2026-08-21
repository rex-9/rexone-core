require "rails_helper"

RSpec.describe PaymentService::Stripe do
  describe "#create_product" do
    it "creates Stripe records and persists the local premium product" do
      service = described_class.new
      stripe_product = instance_double("Stripe::Product", id: "prod_new")
      stripe_price = instance_double("Stripe::Price", id: "price_new")

      allow(Stripe::Product).to receive(:create).and_return(stripe_product)
      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(stripe_price)

      product = service.create_product(
        name: "Premium",
        description: "Premium access",
        price_unit_amount: 2_000,
        currency: "usd",
        cycle: "month",
        active: true
      )

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

      product = service.create_product(
        name: "Free",
        description: "Free access",
        price_unit_amount: 0,
        currency: "usd",
        cycle: "month",
        active: true
      )

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

    it "archives Stripe records when database product persistence fails" do
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

  describe "#update_product" do
    it "archives the previous Stripe price after creating a replacement price" do
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

      expect(result.stripe_price_id).to eq("price_new")
      expect(product.reload.stripe_price_id).to eq("price_new")
      expect(Stripe::Product).to have_received(:update).with(
        "prod_existing",
        hash_including(default_price: "price_new")
      )
      expect(Stripe::Price).to have_received(:update).with("price_old", active: false)
    end

    it "does not create or archive a price when only product fields change" do
      service = described_class.new
      product = create(:payment_product, stripe_product_id: "prod_existing", stripe_price_id: "price_old")

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create)
      allow(Stripe::Price).to receive(:update)

      service.update_product(product.id, name: "Updated product")

      expect(Stripe::Price).not_to have_received(:create)
      expect(Stripe::Price).not_to have_received(:update)
    end

    it "does not create or archive a price when the incoming cycle matches the existing enum value" do
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

      expect(result).to be_free
      expect(result.cycle).to be_nil
      expect(result.stripe_product_id).to eq("prod_paid")
      expect(result.stripe_price_id).to eq("price_free")
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

      expect(result).not_to be_free
      expect(product.reload).not_to be_free
      expect(result.stripe_product_id).to eq("prod_free")
      expect(result.stripe_price_id).to eq("price_new")
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
      expect(product.period_label).to eq("Lifetime")
    end
  end
end
