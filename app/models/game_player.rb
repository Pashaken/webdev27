class GamePlayer < ApplicationRecord
  belongs_to :game, inverse_of: :game_players
  belongs_to :user, inverse_of: :game_players
  has_many :moves, dependent: :restrict_with_error
  has_many :game_dice_states, dependent: :restrict_with_error
  has_many :draw_offers, dependent: :restrict_with_error

  scope :in_finished_games, -> { joins(:game).merge(Game.finished) }
  scope :won, -> { in_finished_games.where("games.result = game_players.color || '_win'") }
  scope :lost, lambda {
    in_finished_games.where("games.result IN ('white_win', 'black_win') AND games.result <> game_players.color || '_win'")
  }
  scope :drawn, -> { in_finished_games.where(games: { result: "draw" }) }

  validates :game, :user, presence: true
  validates :color, inclusion: { in: Game::COLORS }, uniqueness: { scope: :game_id }
  validates :user_id, uniqueness: { scope: :game_id }
  validates :rating_before, :rating_delta, numericality: { only_integer: true }, allow_nil: true

  def opponent
    game.game_players.find { |player| player != self }
  end
end
