class Move < ApplicationRecord
  SQUARE = /\A[a-h][1-8]\z/

  belongs_to :game, inverse_of: :moves
  belongs_to :player, class_name: "User", inverse_of: :moves

  validates :game, :player, presence: true
  validates :ply, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :game_id }
  validates :color, inclusion: { in: Game::COLORS }
  validates :piece, inclusion: { in: Game::DICE_PIECES.values }
  validates :captured, inclusion: { in: Game::DICE_PIECES.values }, allow_nil: true
  validates :from_square, :to_square, format: { with: SQUARE }
  validates :san, :fen_after, presence: true
  validates :die_a, :die_b, :die_used, inclusion: { in: 1..6 }
  validates :spent_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :squares_differ
  validate :die_was_rolled
  validate :piece_matches_die

  def dice
    [ die_a, die_b ]
  end

  def capture?
    captured.present?
  end

  private

  def squares_differ
    errors.add(:to_square, :same_as_from) if from_square.present? && from_square == to_square
  end

  def die_was_rolled
    errors.add(:die_used, :not_rolled) unless dice.include?(die_used)
  end

  def piece_matches_die
    return unless Game::DICE_PIECES.key?(die_used)

    errors.add(:piece, :does_not_match_die) unless piece == Game::DICE_PIECES[die_used]
  end
end
