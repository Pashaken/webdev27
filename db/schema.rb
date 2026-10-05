ActiveRecord::Schema[8.1].define(version: 2026_10_06_120000) do
  enable_extension "pg_catalog.plpgsql"

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "username", limit: 50, null: false
    t.string "password_digest", limit: 255, null: false
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }

    t.unique_constraint ["username"], name: "users_username_key"
  end
end
