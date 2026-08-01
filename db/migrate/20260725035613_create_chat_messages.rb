class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages, id: :uuid do |t|
      t.references :room, null: false, type: :uuid, foreign_key: { to_table: :chat_rooms }
      t.string :role, null: false  # "user" or "assistant"
      t.text :content, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :chat_messages, [ :room_id, :created_at ]
  end
end
