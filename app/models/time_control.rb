class TimeControl < ApplicationRecord
  PRESETS = [ [ "5 минут", "300+0" ], [ "10 минут", "600+0" ], [ "15 + 10", "900+10" ] ].freeze
  DEFAULT_PRESET = "600+0".freeze

  has_many :games, dependent: :restrict_with_error

  validates :initial_seconds, numericality: { only_integer: true, in: 60..10_800 },
                              uniqueness: { scope: :increment_seconds }
  validates :increment_seconds, numericality: { only_integer: true, in: 0..60 }

  def self.lookup(initial_seconds, increment_seconds = 0)
    find_or_create_by!(initial_seconds: initial_seconds, increment_seconds: increment_seconds)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def label
    return "#{initial_seconds / 60} мин" if increment_seconds.zero?

    "#{initial_seconds / 60} + #{increment_seconds}"
  end
end
