class AddKingCapturedEndReason < ActiveRecord::Migration[8.1]
  OLD = "end_reason IN ('checkmate', 'resignation', 'timeout', 'stalemate', 'agreement')".freeze
  NEW = "end_reason IN ('checkmate', 'resignation', 'timeout', 'stalemate', 'agreement', 'king_captured')".freeze

  def up
    remove_check_constraint :games, name: "games_end_reason_check"
    add_check_constraint :games, NEW, name: "games_end_reason_check"
  end

  def down
    remove_check_constraint :games, name: "games_end_reason_check"
    add_check_constraint :games, OLD, name: "games_end_reason_check"
  end
end
