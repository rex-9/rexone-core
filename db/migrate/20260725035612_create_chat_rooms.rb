class CreateChatRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_rooms, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :title, default: "New Conversation"
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :chat_rooms, [ :user_id, :created_at ]
  end
end
