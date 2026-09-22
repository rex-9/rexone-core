# db/migrate/20260916173000_create_coupons.rb
class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.string :code, null: false

      t.integer :coupon_type, null: false, default: 0 # 0: percentage, 1: fixed
      t.integer :amount, null: false
      t.string :currency # null indicates currency-agnostic (applies to product's currency)
      t.jsonb :metadata, default: {}

      t.integer :max_usage, default: 0 # 0 = unlimited
      t.integer :max_usage_per_user, default: 1 # 0 = unlimited
      t.integer :used_count, null: false, default: 0

      t.datetime :expires_at
      t.references :referrer, type: :uuid, foreign_key: { to_table: :users }

      t.uuid :target_role_ids, array: true, default: []
      t.uuid :target_user_ids, array: true, default: []
      t.uuid :target_product_ids, array: true, default: []

      t.string :stripe_coupon_id
      t.boolean :active, null: false, default: true

      # ===== AUDIT =====
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      # ===== SOFT DELETE =====
      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :coupons, :code, unique: true
    add_index :coupons, :stripe_coupon_id
    add_index :coupons, :expires_at
    add_index :coupons, :discarded_at
    add_index :coupons, :target_role_ids, using: :gin
    add_index :coupons, :target_user_ids, using: :gin
    add_index :coupons, :target_product_ids, using: :gin
  end
end
