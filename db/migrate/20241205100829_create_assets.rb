class CreateAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :assets, id: :uuid do |t|
      t.string :name, null: false               # File name (e.g., "google_profile_picture")
      t.string :url, null: false                # URL to access the file (Cloudinary or other)
      t.string :category, null: false           # Enum: "profile", "banner", "merit", "wish", "thank"
      t.string :format, null: false             # "image", "video", "doc", etc.
      t.bigint :size, null: false               # File size in bytes
      t.string :source, null: false, default: "upload"                # "google", "upload", etc...
      t.string :extension                       # File extension (e.g., "jpg", "png")
      t.references :record, polymorphic: true, type: :uuid, null: true  # Polymorphic reference (Merit, Wish, Thanks, etc.)
      t.references :user, type: :uuid, foreign_key: true, null: true    # User who uploaded the file
      t.timestamps
    end

    add_index :assets, :url, unique: true
    add_index :assets, :name, unique: true
  end
end
