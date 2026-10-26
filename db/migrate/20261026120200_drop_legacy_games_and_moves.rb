class DropLegacyGamesAndMoves < ActiveRecord::Migration[8.1]
  def up
    drop_table :moves, if_exists: true
    drop_table :games, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
