class CreatePaymentProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_products, id: :uuid do |t|
      t.string :name, null: false
      t.text :description

      t.integer :price_unit_amount, null: false
      t.string :currency, null: false
      t.string :cycle

      t.string :stripe_product_id, null: false
      t.string :stripe_price_id, null: false

      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :payment_products, :stripe_product_id, unique: true
    add_index :payment_products, :stripe_price_id, unique: true
  end
end
