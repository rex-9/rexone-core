class CreateIamUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_user_roles, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :role, null: false, type: :uuid, foreign_key: { to_table: :iam_roles }

      t.timestamps
    end

    add_index :iam_user_roles, [ :user_id, :role_id ], unique: true
  end
end
