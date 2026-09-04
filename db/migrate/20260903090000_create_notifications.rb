# db/migrate/20260903090000_create_notifications.rb

class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, foreign_key: true, null: false, index: true
      t.string :title
      t.text :message, null: false
      t.string :event
      t.jsonb :data, default: {}, null: false
      t.datetime :read_at
      t.datetime :discarded_at, index: true

      t.uuid :created_by_id, index: true
      t.uuid :updated_by_id, index: true
      t.uuid :discarded_by_id, index: true
      t.uuid :undiscarded_by_id, index: true

      t.timestamps
    end

    add_index :notifications, [ :user_id, :created_at ]
    add_index :notifications, [ :user_id, :read_at ]
    add_index :notifications, :event
  end
end
