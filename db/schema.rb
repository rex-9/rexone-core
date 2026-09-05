# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_28_183500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "uuid-ossp"

  create_table "accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.datetime "expired_at"
    t.datetime "expires_at"
    t.datetime "granted_at", null: false
    t.uuid "product_id", null: false
    t.datetime "revoked_at"
    t.string "status", default: "active", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.uuid "user_id", null: false
    t.index ["created_by_id"], name: "index_accesses_on_created_by_id"
    t.index ["discarded_at"], name: "index_accesses_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_accesses_on_discarded_by_id"
    t.index ["expires_at"], name: "index_accesses_on_expires_at"
    t.index ["product_id"], name: "index_accesses_on_product_id"
    t.index ["status"], name: "index_accesses_on_status"
    t.index ["undiscarded_by_id"], name: "index_accesses_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_accesses_on_updated_by_id"
    t.index ["user_id", "product_id"], name: "index_accesses_on_user_id_and_product_id", unique: true
    t.index ["user_id", "status"], name: "index_accesses_on_user_id_and_status"
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assetable_id"
    t.string "assetable_type"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.integer "duration_secs"
    t.string "extension"
    t.string "format"
    t.string "name", null: false
    t.bigint "size_bytes"
    t.string "source", default: "upload", null: false
    t.string "status", default: "pending", null: false
    t.string "storage_key"
    t.string "type", default: "general", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.string "url", null: false
    t.index ["assetable_type", "assetable_id"], name: "index_assets_on_assetable_type_and_assetable_id"
    t.index ["created_by_id"], name: "index_assets_on_created_by_id"
    t.index ["discarded_at"], name: "index_assets_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_assets_on_discarded_by_id"
    t.index ["name"], name: "index_assets_on_name"
    t.index ["status"], name: "index_assets_on_status"
    t.index ["type"], name: "index_assets_on_type"
    t.index ["undiscarded_by_id"], name: "index_assets_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_assets_on_updated_by_id"
    t.index ["url"], name: "index_assets_on_url", unique: true
  end

  create_table "chat_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.jsonb "metadata", default: {}
    t.string "role", null: false
    t.uuid "room_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["created_by_id"], name: "index_chat_messages_on_created_by_id"
    t.index ["discarded_at"], name: "index_chat_messages_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_chat_messages_on_discarded_by_id"
    t.index ["room_id", "created_at"], name: "index_chat_messages_on_room_id_and_created_at"
    t.index ["room_id"], name: "index_chat_messages_on_room_id"
    t.index ["undiscarded_by_id"], name: "index_chat_messages_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_chat_messages_on_updated_by_id"
  end

  create_table "chat_rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.jsonb "metadata", default: {}
    t.string "title", default: "New Conversation"
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.uuid "user_id", null: false
    t.index ["created_by_id"], name: "index_chat_rooms_on_created_by_id"
    t.index ["discarded_at"], name: "index_chat_rooms_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_chat_rooms_on_discarded_by_id"
    t.index ["undiscarded_by_id"], name: "index_chat_rooms_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_chat_rooms_on_updated_by_id"
    t.index ["user_id", "created_at"], name: "index_chat_rooms_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_chat_rooms_on_user_id"
  end

  create_table "feedbacks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "admin_notes"
    t.string "app_version"
    t.string "browser"
    t.string "category", default: "general", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "device"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "os"
    t.string "page"
    t.string "platform", default: "web", null: false
    t.string "priority", default: "normal", null: false
    t.integer "rating"
    t.string "status", default: "new", null: false
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.uuid "user_id"
    t.index ["category"], name: "index_feedbacks_on_category"
    t.index ["created_at"], name: "index_feedbacks_on_created_at"
    t.index ["created_by_id"], name: "index_feedbacks_on_created_by_id"
    t.index ["discarded_at"], name: "index_feedbacks_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_feedbacks_on_discarded_by_id"
    t.index ["platform"], name: "index_feedbacks_on_platform"
    t.index ["priority"], name: "index_feedbacks_on_priority"
    t.index ["rating"], name: "index_feedbacks_on_rating"
    t.index ["status"], name: "index_feedbacks_on_status"
    t.index ["undiscarded_by_id"], name: "index_feedbacks_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_feedbacks_on_updated_by_id"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "iam_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.string "name", null: false
    t.string "resource", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["created_by_id"], name: "index_iam_permissions_on_created_by_id"
    t.index ["discarded_at"], name: "index_iam_permissions_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_iam_permissions_on_discarded_by_id"
    t.index ["name"], name: "index_iam_permissions_on_name", unique: true
    t.index ["resource", "action"], name: "index_iam_permissions_on_resource_and_action", unique: true
    t.index ["undiscarded_by_id"], name: "index_iam_permissions_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_iam_permissions_on_updated_by_id"
  end

  create_table "iam_role_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.uuid "permission_id", null: false
    t.uuid "role_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["created_by_id"], name: "index_iam_role_permissions_on_created_by_id"
    t.index ["discarded_at"], name: "index_iam_role_permissions_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_iam_role_permissions_on_discarded_by_id"
    t.index ["permission_id"], name: "index_iam_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_iam_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_iam_role_permissions_on_role_id"
    t.index ["undiscarded_by_id"], name: "index_iam_role_permissions_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_iam_role_permissions_on_updated_by_id"
  end

  create_table "iam_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.string "name", null: false
    t.boolean "system", default: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["created_by_id"], name: "index_iam_roles_on_created_by_id"
    t.index ["discarded_at"], name: "index_iam_roles_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_iam_roles_on_discarded_by_id"
    t.index ["name"], name: "index_iam_roles_on_name", unique: true
    t.index ["undiscarded_by_id"], name: "index_iam_roles_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_iam_roles_on_updated_by_id"
  end

  create_table "iam_user_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.uuid "role_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.uuid "user_id", null: false
    t.index ["created_by_id"], name: "index_iam_user_roles_on_created_by_id"
    t.index ["discarded_at"], name: "index_iam_user_roles_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_iam_user_roles_on_discarded_by_id"
    t.index ["role_id"], name: "index_iam_user_roles_on_role_id"
    t.index ["undiscarded_by_id"], name: "index_iam_user_roles_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_iam_user_roles_on_updated_by_id"
    t.index ["user_id", "role_id"], name: "index_iam_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_iam_user_roles_on_user_id"
  end

  create_table "log_clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.jsonb "context", default: {}
    t.jsonb "cookies", default: {}
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "device"
    t.datetime "discarded_at"
    t.string "environment"
    t.datetime "last_occurred_at"
    t.jsonb "local_storage_keys", default: []
    t.string "message", null: false
    t.string "method"
    t.integer "occurrence_count", default: 1
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.string "request_id"
    t.datetime "resolved_at"
    t.uuid "resolved_by_id"
    t.jsonb "session_storage_keys", default: []
    t.string "severity", default: "error", null: false
    t.jsonb "stack_trace", default: []
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.string "url"
    t.string "user_agent"
    t.uuid "user_id"
    t.index ["created_at"], name: "index_log_clients_on_created_at"
    t.index ["created_by_id"], name: "index_log_clients_on_created_by_id"
    t.index ["discarded_at"], name: "index_log_clients_on_discarded_at"
    t.index ["environment"], name: "index_log_clients_on_environment"
    t.index ["local_storage_keys"], name: "index_log_clients_on_local_storage_keys", using: :gin
    t.index ["platform", "severity"], name: "index_log_clients_on_platform_and_severity"
    t.index ["platform"], name: "index_log_clients_on_platform"
    t.index ["resolved_at"], name: "index_log_clients_on_resolved_at"
    t.index ["resolved_by_id"], name: "index_log_clients_on_resolved_by_id"
    t.index ["session_storage_keys"], name: "index_log_clients_on_session_storage_keys", using: :gin
    t.index ["severity"], name: "index_log_clients_on_severity"
    t.index ["updated_by_id"], name: "index_log_clients_on_updated_by_id"
    t.index ["user_id", "created_at"], name: "index_log_clients_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_log_clients_on_user_id"
  end

  create_table "payment_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "currency", null: false
    t.string "cycle"
    t.text "description"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.string "name", null: false
    t.integer "price_unit_amount", null: false
    t.string "stripe_price_id", null: false
    t.string "stripe_product_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["code"], name: "index_payment_products_on_code", unique: true
    t.index ["created_by_id"], name: "index_payment_products_on_created_by_id"
    t.index ["discarded_at"], name: "index_payment_products_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_payment_products_on_discarded_by_id"
    t.index ["stripe_price_id"], name: "index_payment_products_on_stripe_price_id", unique: true
    t.index ["stripe_product_id"], name: "index_payment_products_on_stripe_product_id", unique: true
    t.index ["undiscarded_by_id"], name: "index_payment_products_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_payment_products_on_updated_by_id"
  end

  create_table "payment_subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "cancel_at"
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.string "cycle", null: false
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.datetime "ended_at"
    t.jsonb "metadata", default: {}
    t.jsonb "payment_method_details", default: {}
    t.string "payment_method_id"
    t.string "payment_method_type"
    t.uuid "product_id", null: false
    t.datetime "started_at"
    t.string "status", default: "incomplete", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.uuid "user_id", null: false
    t.index ["created_by_id"], name: "index_payment_subscriptions_on_created_by_id"
    t.index ["current_period_end"], name: "index_payment_subscriptions_on_current_period_end"
    t.index ["discarded_at"], name: "index_payment_subscriptions_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_payment_subscriptions_on_discarded_by_id"
    t.index ["product_id"], name: "index_payment_subscriptions_on_product_id"
    t.index ["status"], name: "index_payment_subscriptions_on_status"
    t.index ["stripe_subscription_id"], name: "index_payment_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["undiscarded_by_id"], name: "index_payment_subscriptions_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_payment_subscriptions_on_updated_by_id"
    t.index ["user_id", "status"], name: "index_payment_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_payment_subscriptions_on_user_id"
  end

  create_table "payment_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_capturable", default: 0
    t.integer "amount_received", default: 0
    t.datetime "canceled_at"
    t.string "client_secret"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "currency", null: false
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.jsonb "metadata", default: {}
    t.datetime "paid_at"
    t.jsonb "payment_method_details", default: {}
    t.string "payment_method_id"
    t.string "payment_method_type"
    t.integer "price_unit_amount", null: false
    t.datetime "processing_at"
    t.uuid "product_id", null: false
    t.datetime "refunded_at"
    t.string "status", default: "requires_payment_method", null: false
    t.string "stripe_charge_id"
    t.string "stripe_customer_id"
    t.string "stripe_payment_intent_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.uuid "user_id", null: false
    t.index ["created_at"], name: "index_payment_transactions_on_created_at"
    t.index ["created_by_id"], name: "index_payment_transactions_on_created_by_id"
    t.index ["discarded_at"], name: "index_payment_transactions_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_payment_transactions_on_discarded_by_id"
    t.index ["payment_method_type"], name: "index_payment_transactions_on_payment_method_type"
    t.index ["product_id"], name: "index_payment_transactions_on_product_id"
    t.index ["status"], name: "index_payment_transactions_on_status"
    t.index ["stripe_charge_id"], name: "index_payment_transactions_on_stripe_charge_id", unique: true
    t.index ["stripe_payment_intent_id"], name: "index_payment_transactions_on_stripe_payment_intent_id", unique: true
    t.index ["undiscarded_by_id"], name: "index_payment_transactions_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_payment_transactions_on_updated_by_id"
    t.index ["user_id", "created_at"], name: "index_payment_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_payment_transactions_on_user_id"
  end

  create_table "payment_webhook_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.string "event_type", null: false
    t.text "last_error"
    t.boolean "livemode", default: false, null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "processing_started_at"
    t.datetime "received_at", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_event_id", null: false
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["created_by_id"], name: "index_payment_webhook_events_on_created_by_id"
    t.index ["discarded_by_id"], name: "index_payment_webhook_events_on_discarded_by_id"
    t.index ["event_type"], name: "index_payment_webhook_events_on_event_type"
    t.index ["received_at"], name: "index_payment_webhook_events_on_received_at"
    t.index ["status", "received_at"], name: "index_payment_webhook_events_on_status_and_received_at"
    t.index ["status"], name: "index_payment_webhook_events_on_status"
    t.index ["stripe_event_id"], name: "index_payment_webhook_events_on_stripe_event_id", unique: true
    t.index ["undiscarded_by_id"], name: "index_payment_webhook_events_on_undiscarded_by_id"
    t.index ["updated_by_id"], name: "index_payment_webhook_events_on_updated_by_id"
  end

  create_table "rails_error_dashboard_applications", force: :cascade do |t|
    t.datetime "created_at"
    t.text "description"
    t.string "name", limit: 255, null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_rails_error_dashboard_applications_on_name", unique: true
  end

  create_table "rails_error_dashboard_cascade_patterns", force: :cascade do |t|
    t.float "avg_delay_seconds"
    t.float "cascade_probability"
    t.bigint "child_error_id", null: false
    t.datetime "created_at", null: false
    t.integer "frequency", default: 1, null: false
    t.datetime "last_detected_at"
    t.bigint "parent_error_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cascade_probability"], name: "index_cascade_patterns_on_probability"
    t.index ["child_error_id"], name: "index_cascade_patterns_on_child"
    t.index ["parent_error_id", "child_error_id"], name: "index_cascade_patterns_on_parent_and_child", unique: true
    t.index ["parent_error_id"], name: "index_cascade_patterns_on_parent"
  end

  create_table "rails_error_dashboard_diagnostic_dumps", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.text "dump_data", null: false
    t.string "note"
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_rails_error_dashboard_diagnostic_dumps_on_application_id"
    t.index ["captured_at"], name: "index_diagnostic_dumps_on_captured_at"
  end

  create_table "rails_error_dashboard_error_baselines", force: :cascade do |t|
    t.string "baseline_type", null: false
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "error_type", null: false
    t.float "mean"
    t.float "percentile_95"
    t.float "percentile_99"
    t.datetime "period_end", null: false
    t.datetime "period_start", null: false
    t.string "platform", null: false
    t.integer "sample_size", default: 0, null: false
    t.float "std_dev"
    t.datetime "updated_at", null: false
    t.index ["error_type", "platform", "baseline_type", "period_start"], name: "index_error_baselines_on_type_platform_baseline_period"
    t.index ["error_type", "platform"], name: "index_error_baselines_on_error_type_and_platform"
    t.index ["period_end"], name: "index_error_baselines_on_period_end"
  end

  create_table "rails_error_dashboard_error_comments", force: :cascade do |t|
    t.string "author_name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "error_log_id", null: false
    t.datetime "updated_at", null: false
    t.index ["error_log_id", "created_at"], name: "index_error_comments_on_error_and_time"
    t.index ["error_log_id"], name: "index_rails_error_dashboard_error_comments_on_error_log_id"
  end

  create_table "rails_error_dashboard_error_logs", force: :cascade do |t|
    t.string "action_name"
    t.string "app_version"
    t.bigint "application_id", null: false
    t.datetime "assigned_at"
    t.string "assigned_to"
    t.text "backtrace"
    t.string "backtrace_signature"
    t.text "breadcrumbs"
    t.string "content_type", limit: 100
    t.string "controller_name"
    t.datetime "created_at", null: false
    t.text "environment_info"
    t.string "error_hash"
    t.string "error_type", null: false
    t.text "exception_cause"
    t.integer "external_issue_number"
    t.string "external_issue_provider", limit: 20
    t.string "external_issue_url"
    t.datetime "first_seen_at"
    t.string "git_sha"
    t.string "hostname", limit: 255
    t.string "http_method", limit: 10
    t.text "instance_variables"
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.text "local_variables"
    t.text "message", null: false
    t.boolean "muted", default: false, null: false
    t.datetime "muted_at"
    t.string "muted_by"
    t.string "muted_reason"
    t.datetime "occurred_at", null: false
    t.integer "occurrence_count", default: 1, null: false
    t.string "platform"
    t.integer "priority_level", default: 0
    t.integer "priority_score"
    t.datetime "reopened_at"
    t.integer "request_duration_ms"
    t.text "request_params"
    t.text "request_url"
    t.text "resolution_comment"
    t.string "resolution_reference"
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.string "resolved_by_name"
    t.float "similarity_score"
    t.datetime "snoozed_until"
    t.string "status", default: "new"
    t.text "system_health"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.integer "user_id"
    t.index "date_trunc('day'::text, occurred_at)", name: "index_error_logs_on_occurred_at_day"
    t.index "date_trunc('hour'::text, occurred_at)", name: "index_error_logs_on_occurred_at_hour"
    t.index ["app_version", "resolved", "occurred_at"], name: "index_error_logs_on_version_resolution_time"
    t.index ["app_version"], name: "index_rails_error_dashboard_error_logs_on_app_version"
    t.index ["application_id", "occurred_at"], name: "index_error_logs_on_app_occurred"
    t.index ["application_id", "resolved"], name: "index_error_logs_on_app_resolved"
    t.index ["application_id"], name: "index_rails_error_dashboard_error_logs_on_application_id"
    t.index ["assigned_to", "status", "occurred_at"], name: "index_error_logs_on_assignment_workflow"
    t.index ["backtrace_signature"], name: "index_rails_error_dashboard_error_logs_on_backtrace_signature"
    t.index ["controller_name", "action_name", "error_hash"], name: "index_error_logs_on_controller_action_hash"
    t.index ["error_hash", "resolved", "occurred_at"], name: "index_error_logs_on_hash_resolved_occurred"
    t.index ["error_hash"], name: "index_rails_error_dashboard_error_logs_on_error_hash"
    t.index ["error_type", "occurred_at"], name: "index_error_logs_on_error_type_and_occurred_at"
    t.index ["error_type"], name: "index_rails_error_dashboard_error_logs_on_error_type"
    t.index ["first_seen_at"], name: "index_rails_error_dashboard_error_logs_on_first_seen_at"
    t.index ["git_sha"], name: "index_rails_error_dashboard_error_logs_on_git_sha"
    t.index ["last_seen_at"], name: "index_rails_error_dashboard_error_logs_on_last_seen_at"
    t.index ["muted"], name: "index_rails_error_dashboard_error_logs_on_muted"
    t.index ["occurred_at"], name: "index_error_logs_on_occurred_at_brin", using: :brin
    t.index ["occurred_at"], name: "index_rails_error_dashboard_error_logs_on_occurred_at"
    t.index ["occurrence_count"], name: "index_rails_error_dashboard_error_logs_on_occurrence_count"
    t.index ["platform", "occurred_at"], name: "index_error_logs_on_platform_and_occurred_at"
    t.index ["platform", "status", "occurred_at"], name: "index_error_logs_on_platform_status_time"
    t.index ["platform"], name: "index_rails_error_dashboard_error_logs_on_platform"
    t.index ["priority_level", "resolved", "occurred_at"], name: "index_error_logs_on_priority_resolution"
    t.index ["priority_score"], name: "index_rails_error_dashboard_error_logs_on_priority_score"
    t.index ["resolved", "occurred_at"], name: "index_error_logs_on_resolved_and_occurred_at"
    t.index ["resolved"], name: "index_rails_error_dashboard_error_logs_on_resolved"
    t.index ["similarity_score"], name: "index_rails_error_dashboard_error_logs_on_similarity_score"
    t.index ["user_id"], name: "index_rails_error_dashboard_error_logs_on_user_id"
  end

  create_table "rails_error_dashboard_error_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "error_log_id", null: false
    t.datetime "occurred_at", null: false
    t.string "request_id"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["error_log_id"], name: "index_error_occurrences_on_error_log"
    t.index ["occurred_at", "error_log_id"], name: "index_error_occurrences_on_time_and_error"
    t.index ["request_id"], name: "index_error_occurrences_on_request"
    t.index ["user_id"], name: "index_error_occurrences_on_user"
  end

  create_table "rails_error_dashboard_rack_attack_events", force: :cascade do |t|
    t.bigint "application_id"
    t.datetime "created_at", null: false
    t.string "discriminator", limit: 191
    t.integer "event_count", default: 0, null: false
    t.string "http_method", limit: 10
    t.datetime "last_seen_at"
    t.string "match_type", limit: 50, null: false
    t.string "path", limit: 191
    t.datetime "period_hour", null: false
    t.string "rule", limit: 250, null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "period_hour"], name: "index_rack_attack_events_on_app_and_hour"
    t.index ["period_hour"], name: "index_rack_attack_events_on_period_hour"
    t.index ["rule", "match_type", "discriminator", "path", "period_hour", "application_id"], name: "index_rack_attack_events_upsert_key", unique: true
    t.index ["rule", "period_hour"], name: "index_rack_attack_events_on_rule_and_hour"
  end

  create_table "rails_error_dashboard_storm_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.bigint "events_counted_only", default: 0
    t.bigint "events_overflow", default: 0
    t.bigint "events_total", default: 0
    t.integer "fingerprints_affected", default: 0
    t.integer "peak_rate_per_minute", default: 0
    t.boolean "reached_open", default: false
    t.datetime "started_at", null: false
    t.text "top_fingerprints"
    t.datetime "updated_at", null: false
    t.index ["ended_at"], name: "index_red_storm_events_on_ended_at"
    t.index ["started_at"], name: "index_red_storm_events_on_started_at"
  end

  create_table "rails_error_dashboard_swallowed_exceptions", force: :cascade do |t|
    t.bigint "application_id"
    t.datetime "created_at", null: false
    t.string "exception_class", limit: 250, null: false
    t.datetime "last_seen_at"
    t.datetime "period_hour", null: false
    t.integer "raise_count", default: 0, null: false
    t.string "raise_location", limit: 250, null: false
    t.integer "rescue_count", default: 0, null: false
    t.string "rescue_location", limit: 250
    t.datetime "updated_at", null: false
    t.index ["application_id", "period_hour"], name: "index_swallowed_exceptions_on_app_and_hour"
    t.index ["exception_class", "period_hour"], name: "index_swallowed_exceptions_on_class_and_hour"
    t.index ["exception_class", "raise_location", "rescue_location", "period_hour", "application_id"], name: "index_swallowed_exceptions_upsert_key", unique: true
    t.index ["period_hour"], name: "index_swallowed_exceptions_on_period_hour"
  end

  create_table "rails_pulse_deployments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at", comment: "When the deployment finished (nil if still in progress or unknown)"
    t.text "metadata", comment: "JSON object of arbitrary deployment metadata"
    t.string "revision", null: false, comment: "Git SHA, tag, or version string"
    t.datetime "started_at", null: false, comment: "When the deployment started"
    t.datetime "updated_at", null: false
    t.index ["revision"], name: "index_rails_pulse_deployments_on_revision"
    t.index ["started_at"], name: "index_rails_pulse_deployments_on_started_at"
  end

  create_table "rails_pulse_job_runs", force: :cascade do |t|
    t.string "adapter", comment: "Queue adapter"
    t.text "arguments", comment: "Serialized arguments"
    t.integer "attempts", default: 0, null: false, comment: "Retry attempts"
    t.datetime "created_at", null: false
    t.decimal "duration", precision: 15, scale: 6, comment: "Execution duration in milliseconds"
    t.datetime "enqueued_at", precision: nil, comment: "When the job was enqueued"
    t.string "error_class", comment: "Error class name"
    t.text "error_message", comment: "Error message"
    t.bigint "job_id", null: false, comment: "Link to job definition"
    t.datetime "occurred_at", precision: nil, null: false, comment: "When the job started"
    t.string "run_id", null: false, comment: "Adapter specific run id"
    t.string "status", null: false, comment: "Execution status"
    t.text "tags", comment: "Execution tags"
    t.datetime "updated_at", null: false
    t.index ["job_id", "occurred_at"], name: "index_rails_pulse_job_runs_on_job_and_occurred"
    t.index ["job_id", "status"], name: "index_rails_pulse_job_runs_on_job_and_status"
    t.index ["job_id"], name: "index_rails_pulse_job_runs_on_job_id"
    t.index ["occurred_at"], name: "index_rails_pulse_job_runs_on_occurred_at"
    t.index ["run_id"], name: "index_rails_pulse_job_runs_on_run_id", unique: true
    t.index ["status"], name: "index_rails_pulse_job_runs_on_status"
  end

  create_table "rails_pulse_jobs", force: :cascade do |t|
    t.decimal "avg_duration", precision: 15, scale: 6, comment: "Average duration in milliseconds"
    t.datetime "created_at", null: false
    t.text "description", comment: "Optional description"
    t.integer "failures_count", default: 0, null: false, comment: "Cache of failed runs"
    t.string "name", null: false, comment: "Job class name"
    t.decimal "p95_duration", precision: 15, scale: 6, comment: "95th percentile duration in milliseconds"
    t.decimal "p99_duration", precision: 15, scale: 6, comment: "99th percentile duration in milliseconds"
    t.string "queue_name", comment: "Default queue"
    t.integer "retries_count", default: 0, null: false, comment: "Cache of retried runs"
    t.integer "runs_count", default: 0, null: false, comment: "Cache of total runs"
    t.text "tags", comment: "JSON array of tags"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_rails_pulse_jobs_on_name", unique: true
    t.index ["queue_name"], name: "index_rails_pulse_jobs_on_queue"
    t.index ["runs_count"], name: "index_rails_pulse_jobs_on_runs_count"
  end

  create_table "rails_pulse_operations", force: :cascade do |t|
    t.text "actual_sql", comment: "Actual SQL that ran for sql operations — comment-stripped, unparameterized, unbounded"
    t.boolean "cache_hit", comment: "Whether a cache_read operation hit the cache"
    t.string "codebase_location", comment: "File and line number (e.g., app/models/user.rb:25)"
    t.datetime "created_at", null: false
    t.decimal "duration", precision: 15, scale: 6, null: false, comment: "Operation duration in milliseconds"
    t.bigint "job_run_id", comment: "Link to a background job execution"
    t.string "label", null: false, comment: "Display label: normalized SQL (≤255) for sql ops, controller#action / render path / cache key etc. for others"
    t.datetime "occurred_at", precision: nil, null: false, comment: "When the request started"
    t.string "operation_type", null: false, comment: "Type of operation (e.g., database, view, gem_call)"
    t.bigint "query_id", comment: "Link to the normalized SQL query"
    t.text "repeated_query_group", comment: "Normalized SQL key identifying an N+1 group"
    t.integer "repetition_count", comment: "Number of times this query pattern repeated in the request"
    t.bigint "request_id", comment: "Link to the request"
    t.integer "row_count", comment: "Number of rows returned (SQL operations, Rails 7.1+)"
    t.float "start_time", default: 0.0, null: false, comment: "Operation start time in milliseconds"
    t.datetime "updated_at", null: false
    t.index ["created_at", "query_id"], name: "idx_operations_for_aggregation"
    t.index ["job_run_id"], name: "index_rails_pulse_operations_on_job_run_id"
    t.index ["occurred_at", "duration", "operation_type"], name: "index_rails_pulse_operations_on_time_duration_type"
    t.index ["operation_type"], name: "index_rails_pulse_operations_on_operation_type"
    t.index ["query_id", "duration", "occurred_at"], name: "index_rails_pulse_operations_query_performance"
    t.index ["query_id", "occurred_at"], name: "index_rails_pulse_operations_on_query_and_time"
    t.index ["request_id"], name: "index_rails_pulse_operations_on_request_id"
    t.check_constraint "request_id IS NOT NULL OR job_run_id IS NOT NULL", name: "rails_pulse_operations_request_or_job_run"
  end

  create_table "rails_pulse_queries", force: :cascade do |t|
    t.datetime "analyzed_at", comment: "When query analysis was last performed"
    t.text "backtrace_analysis", comment: "JSON object with call chain and N+1 detection"
    t.datetime "created_at", null: false
    t.text "explain_plan", comment: "EXPLAIN output from actual SQL execution"
    t.string "hashed_sql", limit: 32, null: false, comment: "MD5 hash of normalized SQL for fast lookups and uniqueness"
    t.text "index_recommendations", comment: "JSON array of database index recommendations"
    t.text "issues", comment: "JSON array of detected performance issues"
    t.text "metadata", comment: "JSON object containing query complexity metrics"
    t.text "n_plus_one_analysis", comment: "JSON object with enhanced N+1 query detection results"
    t.text "normalized_sql", null: false, comment: "Full normalized SQL query string (e.g., SELECT * FROM users WHERE id = ?)"
    t.text "query_stats", comment: "JSON object with query characteristics analysis"
    t.text "suggestions", comment: "JSON array of optimization recommendations"
    t.text "tags", comment: "JSON array of tags for filtering and categorization"
    t.datetime "updated_at", null: false
    t.index ["hashed_sql"], name: "index_rails_pulse_queries_on_hashed_sql", unique: true
  end

  create_table "rails_pulse_requests", force: :cascade do |t|
    t.string "controller_action", comment: "Controller and action handling the request (e.g., PostsController#show)"
    t.datetime "created_at", null: false
    t.decimal "duration", precision: 15, scale: 6, null: false, comment: "Total request duration in milliseconds"
    t.boolean "is_error", default: false, null: false, comment: "True if status >= 500"
    t.datetime "occurred_at", precision: nil, null: false, comment: "When the request started"
    t.string "request_uuid", null: false, comment: "Unique identifier for the request (e.g., UUID)"
    t.integer "response_size_bytes", comment: "HTTP response body size in bytes"
    t.bigint "route_id", null: false, comment: "Link to the route"
    t.integer "status", null: false, comment: "HTTP status code (e.g., 200, 500)"
    t.text "tags", comment: "JSON array of tags for filtering and categorization"
    t.datetime "updated_at", null: false
    t.index ["created_at", "route_id"], name: "idx_requests_for_aggregation"
    t.index ["occurred_at"], name: "index_rails_pulse_requests_on_occurred_at"
    t.index ["request_uuid"], name: "index_rails_pulse_requests_on_request_uuid", unique: true
    t.index ["route_id", "occurred_at"], name: "index_rails_pulse_requests_on_route_id_and_occurred_at"
    t.index ["route_id"], name: "index_rails_pulse_requests_on_route_id"
  end

  create_table "rails_pulse_routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "method", null: false, comment: "HTTP method (e.g., GET, POST)"
    t.string "path", null: false, comment: "Request path (e.g., /posts/index)"
    t.text "tags", comment: "JSON array of tags for filtering and categorization"
    t.datetime "updated_at", null: false
    t.index ["method", "path"], name: "index_rails_pulse_routes_on_method_and_path", unique: true
    t.index ["path"], name: "index_rails_pulse_routes_on_path"
  end

  create_table "rails_pulse_summaries", force: :cascade do |t|
    t.float "avg_duration", comment: "Average duration in milliseconds"
    t.integer "count", default: 0, null: false, comment: "Total number of requests/operations"
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0, comment: "Number of error responses (5xx)"
    t.float "max_duration", comment: "Maximum duration in milliseconds"
    t.float "min_duration", comment: "Minimum duration in milliseconds"
    t.float "p50_duration", comment: "50th percentile duration"
    t.float "p95_duration", comment: "95th percentile duration"
    t.float "p99_duration", comment: "99th percentile duration"
    t.datetime "period_end", null: false, comment: "End of the aggregation period"
    t.datetime "period_start", null: false, comment: "Start of the aggregation period"
    t.string "period_type", null: false, comment: "Aggregation period type: hour, day, week, month"
    t.integer "status_2xx", default: 0, comment: "Number of 2xx responses"
    t.integer "status_3xx", default: 0, comment: "Number of 3xx responses"
    t.integer "status_4xx", default: 0, comment: "Number of 4xx responses"
    t.integer "status_5xx", default: 0, comment: "Number of 5xx responses"
    t.float "stddev_duration", comment: "Standard deviation of duration"
    t.integer "success_count", default: 0, comment: "Number of successful responses"
    t.bigint "summarizable_id", null: false, comment: "Link to Route or Query"
    t.string "summarizable_type", null: false
    t.float "total_duration", comment: "Total duration in milliseconds"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_rails_pulse_summaries_on_created_at"
    t.index ["period_start"], name: "index_rails_pulse_summaries_on_period_start"
    t.index ["period_type", "period_start"], name: "index_rails_pulse_summaries_on_period"
    t.index ["summarizable_id"], name: "index_rails_pulse_summaries_on_summarizable_id"
    t.index ["summarizable_type", "summarizable_id", "period_type", "period_start"], name: "idx_pulse_summaries_unique", unique: true
    t.index ["summarizable_type", "summarizable_id"], name: "index_rails_pulse_summaries_on_summarizable"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "confirmation_code"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.datetime "discarded_at"
    t.uuid "discarded_by_id"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "jti", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "name"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "stripe_customer_id"
    t.string "unconfirmed_email"
    t.datetime "undiscarded_at"
    t.uuid "undiscarded_by_id"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.string "username", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["created_by_id"], name: "index_users_on_created_by_id"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_users_on_discarded_by_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["undiscarded_by_id"], name: "index_users_on_undiscarded_by_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["updated_by_id"], name: "index_users_on_updated_by_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "accesses", "payment_products", column: "product_id"
  add_foreign_key "accesses", "users"
  add_foreign_key "accesses", "users", column: "created_by_id"
  add_foreign_key "accesses", "users", column: "discarded_by_id"
  add_foreign_key "accesses", "users", column: "undiscarded_by_id"
  add_foreign_key "accesses", "users", column: "updated_by_id"
  add_foreign_key "assets", "users", column: "created_by_id"
  add_foreign_key "assets", "users", column: "discarded_by_id"
  add_foreign_key "assets", "users", column: "undiscarded_by_id"
  add_foreign_key "assets", "users", column: "updated_by_id"
  add_foreign_key "chat_messages", "chat_rooms", column: "room_id"
  add_foreign_key "chat_messages", "users", column: "created_by_id"
  add_foreign_key "chat_messages", "users", column: "discarded_by_id"
  add_foreign_key "chat_messages", "users", column: "undiscarded_by_id"
  add_foreign_key "chat_messages", "users", column: "updated_by_id"
  add_foreign_key "chat_rooms", "users"
  add_foreign_key "chat_rooms", "users", column: "created_by_id"
  add_foreign_key "chat_rooms", "users", column: "discarded_by_id"
  add_foreign_key "chat_rooms", "users", column: "undiscarded_by_id"
  add_foreign_key "chat_rooms", "users", column: "updated_by_id"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "iam_permissions", "users", column: "created_by_id"
  add_foreign_key "iam_permissions", "users", column: "discarded_by_id"
  add_foreign_key "iam_permissions", "users", column: "undiscarded_by_id"
  add_foreign_key "iam_permissions", "users", column: "updated_by_id"
  add_foreign_key "iam_role_permissions", "iam_permissions", column: "permission_id"
  add_foreign_key "iam_role_permissions", "iam_roles", column: "role_id"
  add_foreign_key "iam_role_permissions", "users", column: "created_by_id"
  add_foreign_key "iam_role_permissions", "users", column: "discarded_by_id"
  add_foreign_key "iam_role_permissions", "users", column: "undiscarded_by_id"
  add_foreign_key "iam_role_permissions", "users", column: "updated_by_id"
  add_foreign_key "iam_roles", "users", column: "created_by_id"
  add_foreign_key "iam_roles", "users", column: "discarded_by_id"
  add_foreign_key "iam_roles", "users", column: "undiscarded_by_id"
  add_foreign_key "iam_roles", "users", column: "updated_by_id"
  add_foreign_key "iam_user_roles", "iam_roles", column: "role_id"
  add_foreign_key "iam_user_roles", "users"
  add_foreign_key "iam_user_roles", "users", column: "created_by_id"
  add_foreign_key "iam_user_roles", "users", column: "discarded_by_id"
  add_foreign_key "iam_user_roles", "users", column: "undiscarded_by_id"
  add_foreign_key "iam_user_roles", "users", column: "updated_by_id"
  add_foreign_key "log_clients", "users"
  add_foreign_key "log_clients", "users", column: "created_by_id"
  add_foreign_key "log_clients", "users", column: "resolved_by_id"
  add_foreign_key "log_clients", "users", column: "updated_by_id"
  add_foreign_key "payment_products", "users", column: "created_by_id"
  add_foreign_key "payment_products", "users", column: "discarded_by_id"
  add_foreign_key "payment_products", "users", column: "undiscarded_by_id"
  add_foreign_key "payment_products", "users", column: "updated_by_id"
  add_foreign_key "payment_subscriptions", "payment_products", column: "product_id"
  add_foreign_key "payment_subscriptions", "users"
  add_foreign_key "payment_subscriptions", "users", column: "created_by_id"
  add_foreign_key "payment_subscriptions", "users", column: "discarded_by_id"
  add_foreign_key "payment_subscriptions", "users", column: "undiscarded_by_id"
  add_foreign_key "payment_subscriptions", "users", column: "updated_by_id"
  add_foreign_key "payment_transactions", "payment_products", column: "product_id"
  add_foreign_key "payment_transactions", "users"
  add_foreign_key "payment_transactions", "users", column: "created_by_id"
  add_foreign_key "payment_transactions", "users", column: "discarded_by_id"
  add_foreign_key "payment_transactions", "users", column: "undiscarded_by_id"
  add_foreign_key "payment_transactions", "users", column: "updated_by_id"
  add_foreign_key "payment_webhook_events", "users", column: "created_by_id"
  add_foreign_key "payment_webhook_events", "users", column: "discarded_by_id"
  add_foreign_key "payment_webhook_events", "users", column: "undiscarded_by_id"
  add_foreign_key "payment_webhook_events", "users", column: "updated_by_id"
  add_foreign_key "rails_error_dashboard_cascade_patterns", "rails_error_dashboard_error_logs", column: "child_error_id"
  add_foreign_key "rails_error_dashboard_cascade_patterns", "rails_error_dashboard_error_logs", column: "parent_error_id"
  add_foreign_key "rails_error_dashboard_diagnostic_dumps", "rails_error_dashboard_applications", column: "application_id"
  add_foreign_key "rails_error_dashboard_error_comments", "rails_error_dashboard_error_logs", column: "error_log_id"
  add_foreign_key "rails_error_dashboard_error_logs", "rails_error_dashboard_applications", column: "application_id"
  add_foreign_key "rails_error_dashboard_error_occurrences", "rails_error_dashboard_error_logs", column: "error_log_id"
  add_foreign_key "rails_pulse_job_runs", "rails_pulse_jobs", column: "job_id"
  add_foreign_key "rails_pulse_operations", "rails_pulse_job_runs", column: "job_run_id"
  add_foreign_key "rails_pulse_operations", "rails_pulse_queries", column: "query_id"
  add_foreign_key "rails_pulse_operations", "rails_pulse_requests", column: "request_id"
  add_foreign_key "rails_pulse_requests", "rails_pulse_routes", column: "route_id"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "users", column: "created_by_id"
  add_foreign_key "users", "users", column: "discarded_by_id"
  add_foreign_key "users", "users", column: "undiscarded_by_id"
  add_foreign_key "users", "users", column: "updated_by_id"
end
