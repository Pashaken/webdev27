ActiveRecord::Schema[8.1].define(version: 2026_10_20_120200) do
  enable_extension "pg_catalog.plpgsql"

  create_table "games", force: :cascade do |t|
    t.integer "white_player_id"
    t.integer "black_player_id"
    t.string "status", default: "waiting", null: false
    t.string "result"
    t.string "end_reason"
    t.string "turn", default: "white", null: false
    t.string "fen", default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", null: false
    t.boolean "rated", default: true, null: false
    t.integer "initial_seconds", default: 600, null: false
    t.integer "increment_seconds", default: 0, null: false
    t.integer "white_seconds_left", default: 600, null: false
    t.integer "black_seconds_left", default: 600, null: false
    t.integer "dice_a"
    t.integer "dice_b"
    t.integer "chosen_die"
    t.string "draw_offered_by"
    t.integer "white_rating_delta"
    t.integer "black_rating_delta"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["black_player_id"], name: "index_games_on_black_player_id"
    t.index ["status"], name: "index_games_on_status"
    t.index ["white_player_id"], name: "index_games_on_white_player_id"
    t.check_constraint "dice_a >= 1 AND dice_a <= 6 AND dice_b >= 1 AND dice_b <= 6", name: "games_dice_range_check"
    t.check_constraint "result::text = ANY (ARRAY['white_win'::character varying, 'black_win'::character varying, 'draw'::character varying]::text[])", name: "games_result_check"
    t.check_constraint "status::text = ANY (ARRAY['waiting'::character varying, 'active'::character varying, 'finished'::character varying]::text[])", name: "games_status_check"
    t.check_constraint "turn::text = ANY (ARRAY['white'::character varying, 'black'::character varying]::text[])", name: "games_turn_check"
    t.check_constraint "white_player_id <> black_player_id", name: "games_players_differ_check"
    t.check_constraint "white_seconds_left >= 0 AND black_seconds_left >= 0", name: "games_clock_check"
  end

  create_table "moves", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "player_id", null: false
    t.integer "ply", null: false
    t.string "color", null: false
    t.string "piece", limit: 1, null: false
    t.string "from_square", limit: 2, null: false
    t.string "to_square", limit: 2, null: false
    t.string "san", null: false
    t.string "captured", limit: 1
    t.integer "die_a", null: false
    t.integer "die_b", null: false
    t.integer "die_used", null: false
    t.string "fen_after", null: false
    t.integer "spent_seconds", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["game_id", "ply"], name: "index_moves_on_game_id_and_ply", unique: true
    t.index ["game_id"], name: "index_moves_on_game_id"
    t.index ["player_id"], name: "index_moves_on_player_id"
    t.check_constraint "color::text = ANY (ARRAY['white'::character varying, 'black'::character varying]::text[])", name: "moves_color_check"
    t.check_constraint "die_used = die_a OR die_used = die_b", name: "moves_die_used_check"
    t.check_constraint "ply > 0", name: "moves_ply_check"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "username", limit: 50, null: false
    t.string "password_digest", limit: 255, null: false
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.integer "rating", default: 1500, null: false

    t.check_constraint "rating >= 100", name: "users_rating_check"
    t.unique_constraint ["username"], name: "users_username_key"
  end

  add_foreign_key "games", "users", column: "black_player_id"
  add_foreign_key "games", "users", column: "white_player_id"
  add_foreign_key "moves", "games"
  add_foreign_key "moves", "users", column: "player_id"
end
