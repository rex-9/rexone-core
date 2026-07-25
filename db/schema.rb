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

ActiveRecord::Schema[8.1].define(version: 2026_07_24_035612) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "uuid-ossp"

  create_table "accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expired_at"
    t.datetime "expires_at"
    t.datetime "granted_at", null: false
    t.uuid "product_id", null: false
    t.datetime "revoked_at"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_accesses_on_expires_at"
    t.index ["product_id"], name: "index_accesses_on_product_id"
    t.index ["status"], name: "index_accesses_on_status"
    t.index ["user_id", "product_id"], name: "index_accesses_on_user_id_and_product_id", unique: true
    t.index ["user_id", "status"], name: "index_accesses_on_user_id_and_status"
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "extension"
    t.string "format", null: false
    t.string "name", null: false
    t.uuid "record_id"
    t.string "record_type"
    t.bigint "size", null: false
    t.string "source", default: "upload", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.uuid "user_id"
    t.index ["name"], name: "index_assets_on_name", unique: true
    t.index ["record_type", "record_id"], name: "index_assets_on_record"
    t.index ["url"], name: "index_assets_on_url", unique: true
    t.index ["user_id"], name: "index_assets_on_user_id"
  end

  create_table "payment_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "cycle"
    t.text "description"
    t.string "name", null: false
    t.integer "price_unit_amount", null: false
    t.string "stripe_price_id", null: false
    t.string "stripe_product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_price_id"], name: "index_payment_products_on_stripe_price_id", unique: true
    t.index ["stripe_product_id"], name: "index_payment_products_on_stripe_product_id", unique: true
  end

  create_table "payment_subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.string "cycle", null: false
    t.datetime "ended_at"
    t.datetime "next_billing_at"
    t.datetime "paused_at"
    t.jsonb "payment_method_details", default: {}
    t.string "payment_method_id"
    t.string "payment_method_type"
    t.uuid "product_id", null: false
    t.datetime "started_at"
    t.string "status", default: "incomplete", null: false
    t.string "stripe_subscription_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["next_billing_at"], name: "index_payment_subscriptions_on_next_billing_at"
    t.index ["payment_method_type"], name: "index_payment_subscriptions_on_payment_method_type"
    t.index ["product_id"], name: "index_payment_subscriptions_on_product_id"
    t.index ["status"], name: "index_payment_subscriptions_on_status"
    t.index ["stripe_subscription_id"], name: "index_payment_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["user_id", "status"], name: "index_payment_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_payment_subscriptions_on_user_id"
  end

  create_table "payment_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.datetime "paid_at"
    t.jsonb "payment_method_details", default: {}
    t.string "payment_method_id"
    t.string "payment_method_type"
    t.integer "price_unit_amount", null: false
    t.uuid "product_id", null: false
    t.datetime "refunded_at"
    t.string "status", default: "pending", null: false
    t.string "stripe_payment_intent", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["created_at"], name: "index_payment_transactions_on_created_at"
    t.index ["payment_method_type"], name: "index_payment_transactions_on_payment_method_type"
    t.index ["product_id"], name: "index_payment_transactions_on_product_id"
    t.index ["status"], name: "index_payment_transactions_on_status"
    t.index ["stripe_payment_intent"], name: "index_payment_transactions_on_stripe_payment_intent", unique: true
    t.index ["user_id", "created_at"], name: "index_payment_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_payment_transactions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "confirmation_code"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
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
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "accesses", "payment_products", column: "product_id"
  add_foreign_key "accesses", "users"
  add_foreign_key "assets", "users"
  add_foreign_key "payment_subscriptions", "payment_products", column: "product_id"
  add_foreign_key "payment_subscriptions", "users"
  add_foreign_key "payment_transactions", "payment_products", column: "product_id"
  add_foreign_key "payment_transactions", "users"
end
