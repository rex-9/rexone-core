# db/migrate/20260905100001_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.string :event, null: false
      t.string :name, null: false
      t.text :description
      t.string :category, null: false, default: "broadcast"
      t.string :link
      t.boolean :admin, null: false, default: true

      # In-App / Socket
      t.string :in_app_title
      t.text :in_app_body
      t.jsonb :in_app_data, default: {}

      # Push
      t.string :push_title
      t.text :push_body
      t.string :push_template_id

      # Email
      t.string :email_subject
      t.text :email_body
      t.string :email_template_id

      # Metrics / Counters
      t.integer :sent_count, default: 0, null: false
      t.integer :read_count, default: 0, null: false

      # ===== AUDIT =====
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      # ===== SOFT DELETE =====
      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :notifications, :event
    add_index :notifications, :category
    add_index :notifications, :discarded_at
  end
end
