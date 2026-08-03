class CreateIamPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_permissions, id: :uuid do |t|
      t.string :name, null: false       # e.g., "manage_users", "view_assets"
      t.string :action, null: false     # "read", "create", "update", "delete"
      t.string :resource, null: false   # "users", "products", "assets"

      t.timestamps
    end

    add_index :iam_permissions, [ :resource, :action ], unique: true
    add_index :iam_permissions, :name, unique: true
  end
end
