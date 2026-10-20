class EloRating
  K_FACTOR = 32

  def self.expected_score(rating, opponent_rating)
    1.0 / (1 + 10**((opponent_rating - rating) / 400.0))
  end

  def self.delta(rating, opponent_rating, score, k: K_FACTOR)
    (k * (score - expected_score(rating, opponent_rating))).round
  end
end
