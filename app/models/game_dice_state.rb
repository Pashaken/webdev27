class GameDiceState < ApplicationRecord
  belongs_to :game, inverse_of: :game_dice_states
  belongs_to :dice_state
  belongs_to :game_player
  has_one :move, dependent: :restrict_with_error

  validates :game, :dice_state, :game_player, presence: true
  validates :ply, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :game_id }
  validates :chosen_die, inclusion: { in: 1..6 }, allow_nil: true
  validate :player_belongs_to_game
  validate :chosen_die_was_rolled

  def dice
    dice_state.dice
  end

  def chosen?
    chosen_die.present?
  end

  def piece
    Game::DICE_PIECES[chosen_die]
  end

  private

  def player_belongs_to_game
    errors.add(:game_player, :wrong_game) if game_player && game_player.game_id != game_id
  end

  def chosen_die_was_rolled
    return if chosen_die.nil? || dice_state.nil? || dice_state.include?(chosen_die)

    errors.add(:chosen_die, :not_rolled)
  end
end
