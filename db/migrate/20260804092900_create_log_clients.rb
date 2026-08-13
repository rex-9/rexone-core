# db/migrate/xxxx_create_client_logs.rb
class CreateLogClients < ActiveRecord::Migration[8.1]
  def change
    create_table :log_clients, id: :uuid do |t|
      # ===== CORE ERROR DATA =====
      t.string :message, null: false                                  # Error message
      t.string :severity, null: false, default: "error"               # debug | info | warning | error | critical

      # ===== CONTEXT & METADATA =====
      t.jsonb :context, default: {}                                   # Arbitrary context (user action, component, etc.)
      t.jsonb :stack_trace, default: []                               # Array of stack trace lines

      # ===== STORAGE SNAPSHOT =====
      t.jsonb :local_storage_keys, default: []                        # Keys present in localStorage
      t.jsonb :session_storage_keys, default: []                      # Keys present in sessionStorage
      t.jsonb :cookies, default: {}                                   # Cookie key-value pairs

      # ===== PLATFORM & APP =====
      t.string :platform                                              # web | ios | android
      t.string :environment                                           # development | staging | production
      t.string :app_version                                           # App version + build number
      t.string :browser                                               # Browser name + version
      t.string :user_agent                                            # Full user-agent string for parsing

      # ===== USER & SESSION =====
      t.string :request_id                                            # Rails request_id for tracing
      t.references :user,
                    type: :uuid,
                    foreign_key: true,
                    optional: true  # Authenticated user if available

      # ===== URL & ROUTE =====
      t.string :url                                                   # Full URL where error occurred
      t.string :method                                                # HTTP method (GET, POST, etc.)

      # ===== RESOLUTION TRACKING =====
      t.datetime :resolved_at                                         # When the error was resolved
      t.references :resolved_by,
                    type: :uuid,
                    foreign_key: { to_table: :users },
                    optional: true                                    # Who resolved it

      # ===== OCCURRENCE TRACKING =====
      t.integer :occurrence_count, default: 1                         # How many times this error occurred
      t.datetime :last_occurred_at                                    # When it last occurred

      # ===== AUDIT (Auditable) =====
      t.references :created_by,
                    type: :uuid,
                    foreign_key: { to_table: :users }                 # Who created the log
      t.references :updated_by,
                    type: :uuid,
                    foreign_key: { to_table: :users }                 # Who last updated the log

      # ===== SOFT DELETE (Discard) =====
      t.datetime :discarded_at                                        # Soft delete timestamp

      t.timestamps
    end

    # ===== INDEXES =====
    add_index :log_clients, :severity                                 # Filter by severity
    add_index :log_clients, :platform                                 # Filter by platform
    add_index :log_clients, :environment                              # Filter by environment
    add_index :log_clients, :created_at                               # Sort by creation time
    add_index :log_clients, :resolved_at                              # Filter resolved/unresolved
    add_index :log_clients, [ :platform, :severity ]                  # Common filter combo
    add_index :log_clients, [ :user_id, :created_at ]                 # User's errors in chronological order
    add_index :log_clients, :local_storage_keys, using: :gin          # Search by storage keys
    add_index :log_clients, :session_storage_keys, using: :gin        # Search by storage keys
    add_index :log_clients, :discarded_at                             # Soft delete filtering
  end
end
