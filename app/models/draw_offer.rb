class DrawOffer < ApplicationRecord
  belongs_to :game, inverse_of: :draw_offers
  belongs_to :game_player

  validates :game, :game_player, presence: true
  validates :ply, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                  uniqueness: { scope: [ :game_id, :game_player_id ] }
  validate :player_belongs_to_game

  private

  def player_belongs_to_game
    errors.add(:game_player, :wrong_game) if game_player && game_player.game_id != game_id
  end
end
