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
      t.string :assetable_type                                          # Model name (e.g. "user", "course", "lesson", "teacher", "monastery", "message")
      t.uuid :assetable_id                                              # ID of the associated resource
      t.string :status, null: false, default: "pending"                   # Processing Status ("ready", "pending", "processing", "failed")

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
    add_index :assets, [ :assetable_type, :assetable_id ]
    add_index :assets, :discarded_at
    add_index :assets, :status
  end
end
