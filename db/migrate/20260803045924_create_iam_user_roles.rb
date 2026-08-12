class CreateIamUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_user_roles, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :role, null: false, type: :uuid, foreign_key: { to_table: :iam_roles }

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

    add_index :iam_user_roles, [ :user_id, :role_id ], unique: true
    add_index :iam_user_roles, :discarded_at
  end
end
