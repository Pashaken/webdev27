class CreateDrawOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :draw_offers do |t|
      t.references :game, null: false, foreign_key: true
      t.references :game_player, null: false, foreign_key: true
      t.integer :ply, null: false
      t.datetime :created_at, null: false

      t.check_constraint "ply >= 0", name: "draw_offers_ply_check"
    end

    add_index :draw_offers, [ :game_id, :game_player_id, :ply ], unique: true
  end
end
