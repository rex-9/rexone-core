class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: :uuid do |t|
      t.string :username, null: false
      t.string :name
      t.text :bio
      t.string :provider       # "email", "google"
    end

    add_index :users, :username, unique: true
  end
end
