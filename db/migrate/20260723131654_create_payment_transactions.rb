# db/migrate/xxxx_create_payment_transactions.rb
class CreatePaymentTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_transactions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: { to_table: :payment_products }

      # Stripe Payment Intent fields
      t.string :stripe_payment_intent_id, null: false
      t.string :stripe_charge_id
      t.string :stripe_customer_id

      # Payment method
      t.string :payment_method_id
      t.string :payment_method_type
      t.jsonb :payment_method_details, default: {}

      # Payment details
      t.string :currency, null: false
      t.integer :price_unit_amount, null: false
      t.string :status, null: false, default: "requires_payment_method"

      # Payment intent metadata
      t.string :client_secret
      t.jsonb :metadata, default: {}

      # Timestamps
      t.datetime :paid_at
      t.datetime :refunded_at
      t.datetime :canceled_at
      t.datetime :processing_at

      # Amounts
      t.integer :amount_received, default: 0
      t.integer :amount_capturable, default: 0

      t.timestamps
    end

    add_index :payment_transactions, :stripe_payment_intent_id, unique: true
    add_index :payment_transactions, :stripe_charge_id, unique: true
    add_index :payment_transactions, :status
    add_index :payment_transactions, :created_at
    add_index :payment_transactions, :payment_method_type
    add_index :payment_transactions, [ :user_id, :created_at ]
  end
end
