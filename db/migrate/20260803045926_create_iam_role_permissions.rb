class CreateIamRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_role_permissions, id: :uuid do |t|
      t.references :role, null: false, type: :uuid, foreign_key: { to_table: :iam_roles }
      t.references :permission, null: false, type: :uuid, foreign_key: { to_table: :iam_permissions }

      t.timestamps
    end

    add_index :iam_role_permissions, [ :role_id, :permission_id ], unique: true
  end
end
