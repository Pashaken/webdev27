ActiveRecord::Schema[8.1].define(version: 2026_10_27_120000) do
  enable_extension "pg_catalog.plpgsql"

  create_table "dice_states", force: :cascade do |t|
    t.integer "first_die", null: false
    t.integer "second_die", null: false
    t.index ["first_die", "second_die"], name: "index_dice_states_on_first_die_and_second_die", unique: true
    t.check_constraint "first_die >= 1 AND first_die <= 6 AND second_die >= 1 AND second_die <= 6", name: "dice_states_range_check"
  end

  create_table "draw_offers", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "game_player_id", null: false
    t.integer "ply", null: false
    t.datetime "created_at", null: false
    t.index ["game_id", "game_player_id", "ply"], name: "index_draw_offers_on_game_id_and_game_player_id_and_ply", unique: true
    t.index ["game_id"], name: "index_draw_offers_on_game_id"
    t.index ["game_player_id"], name: "index_draw_offers_on_game_player_id"
    t.check_constraint "ply >= 0", name: "draw_offers_ply_check"
  end

  create_table "game_dice_states", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "dice_state_id", null: false
    t.bigint "game_player_id", null: false
    t.integer "ply", null: false
    t.integer "chosen_die"
    t.datetime "created_at", null: false
    t.index ["dice_state_id"], name: "index_game_dice_states_on_dice_state_id"
    t.index ["game_id", "ply"], name: "index_game_dice_states_on_game_id_and_ply", unique: true
    t.index ["game_id"], name: "index_game_dice_states_on_game_id"
    t.index ["game_player_id"], name: "index_game_dice_states_on_game_player_id"
    t.check_constraint "chosen_die >= 1 AND chosen_die <= 6", name: "game_dice_states_chosen_check"
    t.check_constraint "ply > 0", name: "game_dice_states_ply_check"
  end

  create_table "game_players", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "user_id", null: false
    t.string "color", null: false
    t.integer "rating_before"
    t.integer "rating_delta"
    t.datetime "created_at", null: false
    t.index ["game_id", "color"], name: "index_game_players_on_game_id_and_color", unique: true
    t.index ["game_id", "user_id"], name: "index_game_players_on_game_id_and_user_id", unique: true
    t.index ["game_id"], name: "index_game_players_on_game_id"
    t.index ["user_id"], name: "index_game_players_on_user_id"
    t.check_constraint "color::text = ANY (ARRAY['white'::character varying, 'black'::character varying]::text[])", name: "game_players_color_check"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "time_control_id", null: false
    t.boolean "rated", default: true, null: false
    t.string "result"
    t.string "end_reason"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["time_control_id"], name: "index_games_on_time_control_id"
    t.check_constraint "(finished_at IS NULL) = (result IS NULL) AND (finished_at IS NULL) = (end_reason IS NULL)", name: "games_finish_check"
    t.check_constraint "end_reason::text = ANY (ARRAY['checkmate'::character varying, 'resignation'::character varying, 'timeout'::character varying, 'stalemate'::character varying, 'agreement'::character varying, 'king_captured'::character varying]::text[])", name: "games_end_reason_check"
    t.check_constraint "finished_at IS NULL OR started_at IS NOT NULL", name: "games_started_check"
    t.check_constraint "result::text = ANY (ARRAY['white_win'::character varying, 'black_win'::character varying, 'draw'::character varying]::text[])", name: "games_result_check"
  end

  create_table "moves", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "game_player_id", null: false
    t.bigint "game_dice_state_id", null: false
    t.integer "ply", null: false
    t.string "piece", limit: 1, null: false
    t.string "from_square", limit: 2, null: false
    t.string "to_square", limit: 2, null: false
    t.string "promotion", limit: 1
    t.string "captured", limit: 1
    t.string "san", null: false
    t.integer "spent_seconds", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["game_dice_state_id"], name: "index_moves_on_game_dice_state_id", unique: true
    t.index ["game_id", "ply"], name: "index_moves_on_game_id_and_ply", unique: true
    t.index ["game_id"], name: "index_moves_on_game_id"
    t.index ["game_player_id"], name: "index_moves_on_game_player_id"
    t.check_constraint "ply > 0", name: "moves_ply_check"
    t.check_constraint "spent_seconds >= 0", name: "moves_spent_check"
  end

  create_table "time_controls", force: :cascade do |t|
    t.integer "initial_seconds", null: false
    t.integer "increment_seconds", default: 0, null: false
    t.index ["initial_seconds", "increment_seconds"], name: "index_time_controls_on_initial_seconds_and_increment_seconds", unique: true
    t.check_constraint "increment_seconds >= 0 AND increment_seconds <= 60", name: "time_controls_increment_check"
    t.check_constraint "initial_seconds >= 60 AND initial_seconds <= 10800", name: "time_controls_initial_check"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "username", limit: 50, null: false
    t.string "password_digest", limit: 255, null: false
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.integer "rating", default: 1500, null: false

    t.check_constraint "rating >= 100", name: "users_rating_check"
    t.unique_constraint ["username"], name: "users_username_key"
  end

  add_foreign_key "draw_offers", "game_players"
  add_foreign_key "draw_offers", "games"
  add_foreign_key "game_dice_states", "dice_states"
  add_foreign_key "game_dice_states", "game_players"
  add_foreign_key "game_dice_states", "games"
  add_foreign_key "game_players", "games"
  add_foreign_key "game_players", "users"
  add_foreign_key "games", "time_controls"
  add_foreign_key "moves", "game_dice_states"
  add_foreign_key "moves", "game_players"
  add_foreign_key "moves", "games"
end
