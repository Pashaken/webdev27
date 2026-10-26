class DiceState < ApplicationRecord
  has_many :game_dice_states, dependent: :restrict_with_error
  has_many :games, through: :game_dice_states

  validates :first_die, :second_die, inclusion: { in: 1..6 }
  validates :first_die, uniqueness: { scope: :second_die }

  def self.lookup(first_die, second_die)
    find_or_create_by!(first_die: first_die, second_die: second_die)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def dice
    [ first_die, second_die ]
  end

  def include?(value)
    dice.include?(value)
  end
end
