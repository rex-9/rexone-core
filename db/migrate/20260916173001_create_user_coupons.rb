# db/migrate/20260916173001_create_user_coupons.rb
class CreateUserCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :user_coupons, id: :uuid do |t|
      t.references :coupon, null: false, type: :uuid, foreign_key: { to_table: :coupons }
      t.references :user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :product, null: false, type: :uuid, foreign_key: { to_table: :payment_products }

      t.uuid :purchase_id, null: false
      t.integer :purchase_type, null: false, default: 0 # 0: trx, 1: sbs

      t.integer :discount_amount, null: false, default: 0
      t.integer :original_amount, null: false, default: 0
      t.integer :final_amount, null: false, default: 0
      t.string :currency, null: false, default: "usd"

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

    add_index :user_coupons, [ :purchase_id, :purchase_type ]
    add_index :user_coupons, [ :coupon_id, :user_id ]
    add_index :user_coupons, :discarded_at
  end
end
