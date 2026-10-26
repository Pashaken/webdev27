class RecreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves do |t|
      t.references :game, null: false, foreign_key: true
      t.references :game_player, null: false, foreign_key: true
      t.references :game_dice_state, null: false, foreign_key: true, index: { unique: true }
      t.integer :ply, null: false
      t.string :piece, null: false, limit: 1
      t.string :from_square, null: false, limit: 2
      t.string :to_square, null: false, limit: 2
      t.string :promotion, limit: 1
      t.string :captured, limit: 1
      t.string :san, null: false
      t.integer :spent_seconds, null: false, default: 0
      t.datetime :created_at, null: false

      t.check_constraint "ply > 0", name: "moves_ply_check"
      t.check_constraint "spent_seconds >= 0", name: "moves_spent_check"
    end

    add_index :moves, [ :game_id, :ply ], unique: true
  end
end
