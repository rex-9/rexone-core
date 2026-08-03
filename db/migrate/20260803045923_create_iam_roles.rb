class CreateIamRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :iam_roles, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :system, default: false   # System roles can't be deleted

      t.timestamps
    end

    add_index :iam_roles, :name, unique: true
  end
end
