class CreateIamRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_roles, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :system, default: false   # System roles can't be deleted

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

    add_index :iam_roles, :name, unique: true
    add_index :iam_roles, :discarded_at
  end
end
