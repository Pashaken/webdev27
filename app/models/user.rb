class User < ApplicationRecord
  MIN_RATING = 100

  has_secure_password

  has_many :game_players, dependent: :restrict_with_error, inverse_of: :user
  has_many :games, through: :game_players
  has_many :moves, through: :game_players

  normalizes :username, with: ->(username) { username.strip }

  validates :username,
            presence: true,
            length: { in: 3..50 },
            format: { with: /\A[\p{L}\p{N}_.\-]+\z/,
                      message: "может содержать только буквы, цифры и символы _ . -",
                      allow_blank: true },
            uniqueness: { case_sensitive: false }

  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: MIN_RATING }

  def finished_games_count
    game_players.in_finished_games.count
  end

  def wins_count
    game_players.won.count
  end

  def losses_count
    game_players.lost.count
  end

  def draws_count
    game_players.drawn.count
  end

  def win_rate
    finished = finished_games_count
    return 0 if finished.zero?

    (wins_count * 100.0 / finished).round
  end

  def apply_rating_change!(delta)
    new_rating = [ rating + delta, MIN_RATING ].max
    applied = new_rating - rating
    update!(rating: new_rating)
    applied
  end
end
