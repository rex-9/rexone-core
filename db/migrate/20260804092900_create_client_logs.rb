# db/migrate/xxxx_create_client_logs.rb
class CreateClientLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :client_logs, id: :uuid do |t|
      # ===== CORE ERROR DATA =====
      t.string :message, null: false                                  # Error message
      t.string :severity, null: false, default: "error"               # debug | info | warning | error | critical

      # ===== CONTEXT & METADATA =====
      t.jsonb :metadata, default: {}, null: false                     # Deterministic client log metadata
      t.text :stack_trace, array: true, default: []                   # Stack trace lines

      # ===== STORAGE SNAPSHOT =====
      t.string :local_storage_keys, array: true, default: []          # Keys in localStorage
      t.string :session_storage_keys, array: true, default: []        # Keys in sessionStorage
      t.jsonb :cookies, default: {}                                   # Cookie key-value pairs

      # ===== PLATFORM & APP =====
      t.string :platform                                              # web | ios | android
      t.string :environment                                           # development | staging | production
      t.string :browser                                               # Browser name + version
      t.string :os                                                    # OS name
      t.string :os_version                                            # OS version
      t.string :device                                                # Device model
      t.string :user_agent                                            # Full user-agent string

      # ===== USER & SESSION =====
      t.string :request_id                                            # Rails request_id for tracing
      t.references :user,
                    type: :uuid,
                    foreign_key: true                                 # Authenticated user if available

      # ===== Versioning =====
      t.references :version,
                    type: :uuid,
                    foreign_key: { to_table: :client_versions, on_delete: :nullify } # Client::Version if available

      # ===== URL & ROUTE =====
      t.string :url                                                   # Full URL where error occurred
      t.string :method                                                # HTTP method (GET, POST, etc.)

      # ===== RESOLUTION TRACKING =====
      t.datetime :resolved_at                                         # When the error was resolved
      t.references :resolved_by,
                    type: :uuid,
                    foreign_key: { to_table: :users }                 # Who resolved it

      # ===== OCCURRENCE TRACKING =====
      t.integer :occurrence_count, default: 1                         # How many times this error occurred
      t.datetime :last_occurred_at                                    # When it last occurred

      # ===== AUDIT =====
      t.references :created_by,
                    type: :uuid,
                    foreign_key: { to_table: :users }                 # Who created the log
      t.references :updated_by,
                    type: :uuid,
                    foreign_key: { to_table: :users }                 # Who last updated the log

      # ===== SOFT DELETE =====
      t.datetime :discarded_at                                        # Soft delete timestamp

      t.timestamps
    end

    # ===== INDEXES =====
    add_index :client_logs, :severity                                 # Filter by severity
    add_index :client_logs, :platform                                 # Filter by platform
    add_index :client_logs, :environment                              # Filter by environment
    add_index :client_logs, :created_at                               # Sort by creation time
    add_index :client_logs, :resolved_at                              # Filter resolved/unresolved
    add_index :client_logs, [ :platform, :severity ]                  # Common filter combo
    add_index :client_logs, [ :user_id, :created_at ]                 # User's errors in chronological order
    add_index :client_logs, :local_storage_keys, using: :gin          # Search by storage keys
    add_index :client_logs, :session_storage_keys, using: :gin        # Search by storage keys
    add_index :client_logs, :discarded_at                             # Soft delete filtering
  end
end
