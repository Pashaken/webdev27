class CreateGamePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :game_players do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, type: :integer, null: false, foreign_key: true
      t.string :color, null: false
      t.integer :rating_before
      t.integer :rating_delta
      t.datetime :created_at, null: false

      t.check_constraint "color IN ('white', 'black')", name: "game_players_color_check"
    end

    add_index :game_players, [ :game_id, :color ], unique: true
    add_index :game_players, [ :game_id, :user_id ], unique: true
  end
end
