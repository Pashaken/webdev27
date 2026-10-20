class User < ApplicationRecord
  MIN_RATING = 100

  has_secure_password

  has_many :games_as_white, class_name: "Game", foreign_key: :white_player_id,
           inverse_of: :white_player, dependent: :restrict_with_error
  has_many :games_as_black, class_name: "Game", foreign_key: :black_player_id,
           inverse_of: :black_player, dependent: :restrict_with_error
  has_many :moves, foreign_key: :player_id, inverse_of: :player, dependent: :restrict_with_error

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

  def games
    Game.involving(self)
  end

  def finished_games_count
    games.finished.count
  end

  def wins_count
    games.finished.won_by(self).count
  end

  def losses_count
    games.finished.lost_by(self).count
  end

  def draws_count
    games.finished.drawn.count
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
