# db/migrate/20260905100002_create_user_notifications.rb
class CreateUserNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :user_notifications, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :notification, type: :uuid, foreign_key: { on_delete: :nullify }

      t.string :title, null: false
      t.text :message, null: false
      t.string :link
      t.string :clients, array: true, null: false, default: %w[web mobile]
      t.jsonb :metadata, default: {}, null: false
      t.string :operation_id
      t.string :operation_type
      t.string :operation_status

      t.datetime :read_at

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

    add_index :user_notifications, [ :user_id, :created_at ]
    add_index :user_notifications, [ :user_id, :read_at ]
    add_index :user_notifications, [ :user_id, :operation_id ], unique: true, where: "operation_id IS NOT NULL"
    add_index :user_notifications, :discarded_at
    add_index :user_notifications, :clients, using: :gin
  end
end
