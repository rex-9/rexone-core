class CreateAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :accesses, id: :uuid do |t|
      t.references :user,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :product,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :payment_products }

      t.string :status, null: false, default: "active"

      t.datetime :granted_at, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :expired_at

      t.timestamps
    end

    add_index :accesses, :status
    add_index :accesses, :expires_at
    add_index :accesses, [ :user_id, :product_id ], unique: true # TODO: improve
    add_index :accesses, [ :user_id, :status ]
  end
end
