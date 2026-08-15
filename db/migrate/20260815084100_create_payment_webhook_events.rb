class CreatePaymentWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_webhook_events, id: :uuid do |t|
      # Stripe event identity
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.boolean :livemode, null: false, default: false

      # Processing
      t.string :status, null: false, default: "pending"
      t.jsonb :payload, null: false, default: {}
      t.integer :attempt_count, null: false, default: 0

      # Processing result
      t.datetime :received_at, null: false
      t.datetime :processing_started_at
      t.datetime :processed_at
      t.text :last_error

      # ===== AUDIT =====
      t.references :created_by,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.references :updated_by,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.references :discarded_by,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.references :undiscarded_by,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      # ===== SOFT DELETE =====
      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :payment_webhook_events,
              :stripe_event_id,
              unique: true

    add_index :payment_webhook_events, :event_type
    add_index :payment_webhook_events, :status
    add_index :payment_webhook_events, :received_at
    add_index :payment_webhook_events, [ :status, :received_at ]
  end
end
