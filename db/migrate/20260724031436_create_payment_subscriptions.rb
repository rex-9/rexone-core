class CreatePaymentSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_subscriptions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: { to_table: :payment_products }

      t.string :stripe_subscription_id, null: false
      t.string :status, null: false, default: "incomplete"
      t.string :cycle, null: false  # "month" or "year"

      t.string :payment_method_id
      t.string :payment_method_type
      t.jsonb :payment_method_details, default: {}

      t.datetime :next_billing_at
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :payment_subscriptions, :stripe_subscription_id, unique: true
    add_index :payment_subscriptions, :status
    add_index :payment_subscriptions, :next_billing_at
    add_index :payment_subscriptions, :payment_method_type
    add_index :payment_subscriptions, [ :user_id, :status ]
  end
end
