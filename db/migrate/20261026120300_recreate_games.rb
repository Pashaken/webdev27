class RecreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :time_control, null: false, foreign_key: true
      t.boolean :rated, null: false, default: true
      t.string :result
      t.string :end_reason
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps

      t.check_constraint "result IN ('white_win', 'black_win', 'draw')", name: "games_result_check"
      t.check_constraint "end_reason IN ('checkmate', 'resignation', 'timeout', 'stalemate', 'agreement')", name: "games_end_reason_check"
      t.check_constraint "(finished_at IS NULL) = (result IS NULL) AND (finished_at IS NULL) = (end_reason IS NULL)", name: "games_finish_check"
      t.check_constraint "finished_at IS NULL OR started_at IS NOT NULL", name: "games_started_check"
    end
  end
end
