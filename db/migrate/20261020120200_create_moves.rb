class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, type: :integer, null: false, foreign_key: { to_table: :users }
      t.integer :ply, null: false
      t.string :color, null: false
      t.string :piece, null: false, limit: 1
      t.string :from_square, null: false, limit: 2
      t.string :to_square, null: false, limit: 2
      t.string :san, null: false
      t.string :captured, limit: 1
      t.integer :die_a, null: false
      t.integer :die_b, null: false
      t.integer :die_used, null: false
      t.string :fen_after, null: false
      t.integer :spent_seconds, null: false, default: 0
      t.datetime :created_at, null: false

      t.check_constraint "ply > 0", name: "moves_ply_check"
      t.check_constraint "color IN ('white', 'black')", name: "moves_color_check"
      t.check_constraint "die_used IN (die_a, die_b)", name: "moves_die_used_check"
    end

    add_index :moves, [ :game_id, :ply ], unique: true
  end
end
