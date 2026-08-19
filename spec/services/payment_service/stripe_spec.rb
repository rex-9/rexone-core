require "rails_helper"

RSpec.describe PaymentService::Stripe do
  describe "#create_product" do
    it "creates a local free product without calling Stripe" do
      service = described_class.new

      allow(Stripe::Product).to receive(:create)
      allow(Stripe::Price).to receive(:create)

      product = service.create_product(
        name: "Free",
        description: "Free access",
        price_unit_amount: 0,
        currency: "usd",
        cycle: nil,
        active: true
      )

      expect(product).to be_persisted
      expect(product).to be_free
      expect(product.display_price).to eq("Free")
      expect(product.stripe_product_id).to eq(Payment::Product::LOCAL_FREE_PRODUCT_ID)
      expect(product.stripe_price_id).to eq(Payment::Product::LOCAL_FREE_PRICE_ID)
      expect(Stripe::Product).not_to have_received(:create)
      expect(Stripe::Price).not_to have_received(:create)
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

    it "archives Stripe records and converts a paid product to local free" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: "prod_paid",
        stripe_price_id: "price_paid",
        price_unit_amount: 1_000
      )

      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:update)

      result = service.update_product(product.id, price_unit_amount: 0)

      expect(result).to be_free
      expect(result.stripe_product_id).to eq(Payment::Product::LOCAL_FREE_PRODUCT_ID)
      expect(result.stripe_price_id).to eq(Payment::Product::LOCAL_FREE_PRICE_ID)
      expect(Stripe::Product).to have_received(:update).with("prod_paid", active: false)
      expect(Stripe::Price).to have_received(:update).with("price_paid", active: false)
    end

    it "creates Stripe records when converting a free product to paid" do
      service = described_class.new
      product = create(
        :payment_product,
        stripe_product_id: Payment::Product::LOCAL_FREE_PRODUCT_ID,
        stripe_price_id: Payment::Product::LOCAL_FREE_PRICE_ID,
        price_unit_amount: 0
      )
      stripe_product = instance_double("Stripe::Product", id: "prod_new")
      stripe_price = instance_double("Stripe::Price", id: "price_new")

      allow(Stripe::Product).to receive(:create).and_return(stripe_product)
      allow(Stripe::Product).to receive(:update)
      allow(Stripe::Price).to receive(:create).and_return(stripe_price)

      result = service.update_product(product.id, price_unit_amount: 2_000, currency: "usd", cycle: "month")

      expect(result).not_to be_free
      expect(result.stripe_product_id).to eq("prod_new")
      expect(result.stripe_price_id).to eq("price_new")
      expect(Stripe::Product).to have_received(:create).with(
        hash_including(name: product.name, active: product.active)
      )
      expect(Stripe::Price).to have_received(:create)
    end
  end
end
