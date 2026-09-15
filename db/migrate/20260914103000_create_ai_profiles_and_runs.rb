class CreateAiProfilesAndRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_profiles, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.string :provider, null: false, default: "deepseek"
      t.string :model, null: false
      t.decimal :temperature, precision: 4, scale: 2, null: false, default: 0.7
      t.integer :max_output_tokens, null: false, default: 2000
      t.integer :context_max_tokens, null: false, default: 8000
      t.integer :history_max_messages, null: false, default: 20
      t.integer :timeout_seconds, null: false, default: 30
      t.text :system_prompt
      t.jsonb :settings, null: false, default: {}
      t.datetime :discarded_at
      t.uuid :created_by_id
      t.uuid :updated_by_id
      t.uuid :discarded_by_id
      t.datetime :undiscarded_at
      t.uuid :undiscarded_by_id

      t.timestamps
    end

    add_index :ai_profiles, :key, unique: true
    add_index :ai_profiles, :enabled
    add_index :ai_profiles, :discarded_at
    add_foreign_key :ai_profiles, :users, column: :created_by_id
    add_foreign_key :ai_profiles, :users, column: :updated_by_id
    add_foreign_key :ai_profiles, :users, column: :discarded_by_id
    add_foreign_key :ai_profiles, :users, column: :undiscarded_by_id

    add_reference :chat_messages, :ai_profile, type: :uuid, foreign_key: { to_table: :ai_profiles }

    create_table :ai_runs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :ai_profile, null: false, type: :uuid, foreign_key: { to_table: :ai_profiles }
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :chat_message, type: :uuid, foreign_key: { to_table: :chat_messages }
      t.string :feature, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :status, null: false
      t.integer :input_messages_count
      t.integer :input_chars
      t.integer :output_chars
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.integer :latency_ms
      t.text :error
      t.jsonb :request_metadata, null: false, default: {}
      t.datetime :discarded_at
      t.uuid :created_by_id
      t.uuid :updated_by_id
      t.uuid :discarded_by_id
      t.datetime :undiscarded_at
      t.uuid :undiscarded_by_id

      t.timestamps
    end

    add_index :ai_runs, :feature
    add_index :ai_runs, :status
    add_index :ai_runs, :created_at
    add_index :ai_runs, :discarded_at
    add_foreign_key :ai_runs, :users, column: :created_by_id
    add_foreign_key :ai_runs, :users, column: :updated_by_id
    add_foreign_key :ai_runs, :users, column: :discarded_by_id
    add_foreign_key :ai_runs, :users, column: :undiscarded_by_id
  end
end
