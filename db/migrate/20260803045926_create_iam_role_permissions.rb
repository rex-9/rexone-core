class CreateIamRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_role_permissions, id: :uuid do |t|
      t.references :role, null: false, type: :uuid, foreign_key: { to_table: :iam_roles }
      t.references :permission, null: false, type: :uuid, foreign_key: { to_table: :iam_permissions }

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

    add_index :iam_role_permissions, [ :role_id, :permission_id ], unique: true
    add_index :iam_role_permissions, :discarded_at
  end
end
