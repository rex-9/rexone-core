class CreateIamPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_permissions, id: :uuid do |t|
      t.string :name, null: false       # e.g., "read_users", "create_products"
      t.string :action, null: false     # "read", "create", "update", "delete"
      t.string :resource, null: false   # "users", "products", "assets"

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

    add_index :iam_permissions, [ :resource, :action ], unique: true
    add_index :iam_permissions, :name, unique: true
    add_index :iam_permissions, :discarded_at
  end
end
