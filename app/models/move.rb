class Move < ApplicationRecord
  SQUARE = /\A[a-h][1-8]\z/
  PROMOTION_PIECES = %w[n b r q].freeze

  belongs_to :game, inverse_of: :moves
  belongs_to :game_player
  belongs_to :game_dice_state

  delegate :user, :color, to: :game_player
  delegate :dice, to: :game_dice_state

  validates :game, :game_player, :game_dice_state, presence: true
  validates :ply, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :game_id }
  validates :piece, inclusion: { in: Game::DICE_PIECES.values }
  validates :captured, inclusion: { in: Game::DICE_PIECES.values }, allow_nil: true
  validates :promotion, inclusion: { in: PROMOTION_PIECES }, allow_nil: true
  validates :from_square, :to_square, format: { with: SQUARE }
  validates :san, presence: true
  validates :spent_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :squares_differ
  validate :belongs_to_one_game
  validate :roll_matches_move
  validate :piece_matches_die
  validate :promotion_matches_move

  def die_used
    game_dice_state&.chosen_die
  end

  def capture?
    captured.present?
  end

  private

  def squares_differ
    errors.add(:to_square, :same_as_from) if from_square.present? && from_square == to_square
  end

  def belongs_to_one_game
    errors.add(:game_player, :wrong_game) if game_player && game_player.game_id != game_id
    errors.add(:game_dice_state, :wrong_game) if game_dice_state && game_dice_state.game_id != game_id
  end

  def roll_matches_move
    return if game_dice_state.nil?

    errors.add(:game_dice_state, :other_player) if game_player && game_dice_state.game_player_id != game_player.id
    errors.add(:ply, :does_not_match_roll) if ply.present? && ply != game_dice_state.ply
  end

  def piece_matches_die
    return if game_dice_state.nil?

    if die_used.nil?
      errors.add(:game_dice_state, :no_chosen_die)
    elsif piece != Game::DICE_PIECES[die_used]
      errors.add(:piece, :does_not_match_die)
    end
  end

  def promotion_matches_move
    reaches_last_rank = piece == "p" && %w[1 8].include?(to_square.to_s[1])

    errors.add(:promotion, :blank) if reaches_last_rank && promotion.blank?
    errors.add(:promotion, :present) if !reaches_last_rank && promotion.present?
  end
end
