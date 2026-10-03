# db/migrate/20260705190001_create_client_user_versions.rb
class CreateClientUserVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :client_user_versions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :platform, null: false
      t.string :number, null: false
      t.integer :build_number
      t.references :version, type: :uuid, foreign_key: { to_table: :client_versions, on_delete: :nullify }
      t.datetime :last_seen_at, null: false

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :client_user_versions, [ :user_id, :platform ], unique: true
    add_index :client_user_versions, :number
    add_index :client_user_versions, :last_seen_at
    add_index :client_user_versions, :discarded_at
  end
end
