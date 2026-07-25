class CreatePaymentTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_transactions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: { to_table: :payment_products }

      t.string :stripe_payment_intent, null: false
      t.string :payment_method_id
      t.string :payment_method_type
      t.jsonb :payment_method_details, default: {}

      t.string :currency, null: false
      t.integer :price_unit_amount, null: false
      t.string :status, null: false, default: "pending"

      t.datetime :paid_at
      t.datetime :refunded_at

      t.timestamps
    end

    add_index :payment_transactions, :stripe_payment_intent, unique: true
    add_index :payment_transactions, :status
    add_index :payment_transactions, :created_at
    add_index :payment_transactions, :payment_method_type
    add_index :payment_transactions, [ :user_id, :created_at ]
  end
end
