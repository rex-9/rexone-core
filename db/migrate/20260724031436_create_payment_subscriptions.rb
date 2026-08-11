# db/migrate/xxxx_create_payment_subscriptions.rb
class CreatePaymentSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_subscriptions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: { to_table: :payment_products }

      # Stripe fields that actually exist in the object
      t.string :stripe_subscription_id, null: false
      t.string :stripe_customer_id
      t.jsonb :metadata, default: {}

      t.string :status, null: false, default: "incomplete"
      t.string :cycle, null: false  # "month" or "year"

      # Payment method
      t.string :payment_method_id
      t.string :payment_method_type
      t.jsonb :payment_method_details, default: {}

      # These fields exist in the Stripe object
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :payment_subscriptions, :stripe_subscription_id, unique: true
    add_index :payment_subscriptions, :status
    add_index :payment_subscriptions, :current_period_end
    add_index :payment_subscriptions, [ :user_id, :status ]
  end
end
