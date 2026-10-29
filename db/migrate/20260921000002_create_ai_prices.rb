# frozen_string_literal: true

class CreateAiPrices < ActiveRecord::Migration[8.1]
  def up
    create_table :ai_prices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :provider, null: false
      t.string :model, null: false
      t.string :currency, default: "usd", null: false
      t.decimal :input_cost_per_million, precision: 12, scale: 6, default: 0.0, null: false
      t.decimal :cached_cost_per_million, precision: 12, scale: 6, default: 0.0, null: false
      t.decimal :output_cost_per_million, precision: 12, scale: 6, default: 0.0, null: false
      t.datetime :discarded_at
      t.uuid :created_by_id
      t.uuid :updated_by_id
      t.uuid :discarded_by_id
      t.datetime :undiscarded_at
      t.uuid :undiscarded_by_id

      t.timestamps
    end

    add_index :ai_prices, [ :provider, :model ], unique: true, where: "discarded_at IS NULL", name: "index_ai_prices_on_provider_and_model"
    add_index :ai_prices, :discarded_at
    add_foreign_key :ai_prices, :users, column: :created_by_id
    add_foreign_key :ai_prices, :users, column: :updated_by_id
    add_foreign_key :ai_prices, :users, column: :discarded_by_id
    add_foreign_key :ai_prices, :users, column: :undiscarded_by_id
  end

  def down
    drop_table :ai_prices if table_exists?(:ai_prices)
    remove_column :ai_runs, :cost if column_exists?(:ai_runs, :cost)
  end
end
