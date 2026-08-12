class CreateChatRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_rooms, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :title, default: "New Conversation"
      t.jsonb :metadata, default: {}

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

    add_index :chat_rooms, [ :user_id, :created_at ]
    add_index :chat_rooms, :discarded_at
  end
end
