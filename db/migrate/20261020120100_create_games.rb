class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :white_player, type: :integer, foreign_key: { to_table: :users }
      t.references :black_player, type: :integer, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "waiting"
      t.string :result
      t.string :end_reason
      t.string :turn, null: false, default: "white"
      t.string :fen, null: false, default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
      t.boolean :rated, null: false, default: true
      t.integer :initial_seconds, null: false, default: 600
      t.integer :increment_seconds, null: false, default: 0
      t.integer :white_seconds_left, null: false, default: 600
      t.integer :black_seconds_left, null: false, default: 600
      t.integer :dice_a
      t.integer :dice_b
      t.integer :chosen_die
      t.string :draw_offered_by
      t.integer :white_rating_delta
      t.integer :black_rating_delta
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps

      t.check_constraint "status IN ('waiting', 'active', 'finished')", name: "games_status_check"
      t.check_constraint "turn IN ('white', 'black')", name: "games_turn_check"
      t.check_constraint "result IN ('white_win', 'black_win', 'draw')", name: "games_result_check"
      t.check_constraint "white_player_id <> black_player_id", name: "games_players_differ_check"
      t.check_constraint "dice_a BETWEEN 1 AND 6 AND dice_b BETWEEN 1 AND 6", name: "games_dice_range_check"
      t.check_constraint "white_seconds_left >= 0 AND black_seconds_left >= 0", name: "games_clock_check"
    end

    add_index :games, :status
  end
end
