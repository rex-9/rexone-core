class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages, id: :uuid do |t|
      t.references :room, null: false, type: :uuid, foreign_key: { to_table: :chat_rooms }
      t.string :role, null: false  # "user" or "assistant"
      t.text :content, null: false
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

    add_index :chat_messages, [ :room_id, :created_at ]
    add_index :chat_messages, :discarded_at
  end
end
