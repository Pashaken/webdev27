class CreateGameDiceStates < ActiveRecord::Migration[8.1]
  def change
    create_table :game_dice_states do |t|
      t.references :game, null: false, foreign_key: true
      t.references :dice_state, null: false, foreign_key: true
      t.references :game_player, null: false, foreign_key: true
      t.integer :ply, null: false
      t.integer :chosen_die
      t.datetime :created_at, null: false

      t.check_constraint "ply > 0", name: "game_dice_states_ply_check"
      t.check_constraint "chosen_die BETWEEN 1 AND 6", name: "game_dice_states_chosen_check"
    end

    add_index :game_dice_states, [ :game_id, :ply ], unique: true
  end
end
