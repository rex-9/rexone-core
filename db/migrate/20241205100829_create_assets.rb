class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets, id: :uuid do |t|
      t.string :storage_key                                             # Object key / identifier in object storage (Garage, S3, R2, Cloudinary)
      t.string :name, null: false                                       # File name / identifier
      t.string :url, null: false                                        # Public URL to access the file
      t.string :type, null: false, default: "general"                   # "avatar", "cover", "card", "audio", "video", "attachment", "general"
      t.string :format                                                  # "image", "audio", "video", "doc" (null if unclassified)
      t.bigint :size_bytes                                              # File size in bytes
      t.integer :duration_secs                                          # Duration in seconds (for audio / video)
      t.string :source, null: false, default: "upload"                  # "google", "upload", etc.
      t.string :extension                                               # File extension (e.g., "jpg", "mp3", "png")
      t.string :resource_model                                          # Model name (e.g. "user", "course", "lesson", "teacher", "monastery", "message")
      t.uuid :resource_id                                               # ID of the associated resource

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

    add_index :assets, :url, unique: true
    add_index :assets, :name
    add_index :assets, :type
    add_index :assets, [ :resource_model, :resource_id ]
    add_index :assets, :discarded_at
  end
end
