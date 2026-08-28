# db/migrate/20260828183500_create_feedbacks.rb

class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, foreign_key: true, null: true, index: true
      t.text :content, null: false
      t.integer :rating, null: true
      t.string :category, null: false, default: "general"
      t.string :priority, null: false, default: "normal"
      t.string :status, null: false, default: "new"
      t.string :platform, null: false, default: "web"
      t.string :app_version
      t.string :os
      t.string :device
      t.string :browser
      t.string :page
      t.jsonb :metadata, default: {}, null: false
      t.text :admin_notes

      # Discard (Soft Delete)
      t.datetime :discarded_at, index: true

      # Audited fields
      t.uuid :created_by_id, index: true
      t.uuid :updated_by_id, index: true
      t.uuid :discarded_by_id, index: true
      t.uuid :undiscarded_by_id, index: true

      t.timestamps
    end

    add_index :feedbacks, :status
    add_index :feedbacks, :category
    add_index :feedbacks, :priority
    add_index :feedbacks, :platform
    add_index :feedbacks, :rating
    add_index :feedbacks, :created_at
  end
end
