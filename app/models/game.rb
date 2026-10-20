class Game < ApplicationRecord
  class Error < StandardError; end

  COLORS = %w[white black].freeze
  RESULTS = %w[white_win black_win draw].freeze
  END_REASONS = %w[checkmate resignation timeout stalemate agreement].freeze
  DICE_PIECES = { 1 => "p", 2 => "n", 3 => "b", 4 => "r", 5 => "q", 6 => "k" }.freeze

  enum :status, { waiting: "waiting", active: "active", finished: "finished" }, default: "waiting", validate: true

  belongs_to :white_player, class_name: "User", optional: true, inverse_of: :games_as_white
  belongs_to :black_player, class_name: "User", optional: true, inverse_of: :games_as_black
  has_many :moves, -> { order(:ply) }, dependent: :destroy, inverse_of: :game

  scope :involving, ->(user) { where("white_player_id = :id OR black_player_id = :id", id: user.id) }
  scope :won_by, ->(user) {
    where("(white_player_id = :id AND result = 'white_win') OR (black_player_id = :id AND result = 'black_win')", id: user.id)
  }
  scope :lost_by, ->(user) {
    where("(white_player_id = :id AND result = 'black_win') OR (black_player_id = :id AND result = 'white_win')", id: user.id)
  }
  scope :drawn, -> { where(result: "draw") }

  before_validation :start_clocks, on: :create

  validates :turn, inclusion: { in: COLORS }
  validates :result, inclusion: { in: RESULTS }, allow_nil: true
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true
  validates :draw_offered_by, inclusion: { in: COLORS }, allow_nil: true
  validates :fen, presence: true
  validates :initial_seconds, numericality: { only_integer: true, in: 60..10_800 }
  validates :increment_seconds, numericality: { only_integer: true, in: 0..60 }
  validates :white_seconds_left, :black_seconds_left, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :dice_a, :dice_b, :chosen_die, inclusion: { in: 1..6 }, allow_nil: true
  validate :player_present
  validate :players_differ
  validate :opponent_present_once_started
  validate :result_matches_status
  validate :dice_come_in_pairs
  validate :chosen_die_was_rolled

  def self.open_for(creator:, color: "random", random: Random, **settings)
    color = COLORS[random.rand(2)] if color.to_s == "random"
    raise ArgumentError, "неизвестный цвет: #{color}" unless COLORS.include?(color.to_s)

    create!(settings.merge("#{color}_player": creator))
  end

  def join!(user)
    raise Error, "партия уже началась" unless waiting?
    raise Error, "нельзя играть с самим собой" if participant?(user)

    update!(free_seat => user, status: "active", started_at: Time.current)
  end

  def participant?(user)
    color_of(user).present?
  end

  def color_of(user)
    return if user.nil? || user.id.nil?

    if user.id == white_player_id
      "white"
    elsif user.id == black_player_id
      "black"
    end
  end

  def player_of(color)
    color == "white" ? white_player : black_player
  end

  def opponent_of(user)
    color = color_of(user)
    player_of(opposite(color)) if color
  end

  def current_player
    player_of(turn)
  end

  def my_turn?(user)
    active? && color_of(user) == turn
  end

  def seconds_left(color)
    public_send("#{color}_seconds_left")
  end

  def dice_rolled?
    dice_a.present? && dice_b.present?
  end

  def dice
    dice_rolled? ? [ dice_a, dice_b ] : []
  end

  def allowed_piece
    DICE_PIECES[chosen_die]
  end

  def roll_dice!(user, random: Random)
    ensure_turn!(user)
    raise Error, "кубики уже брошены" if dice_rolled?

    update!(dice_a: random.rand(1..6), dice_b: random.rand(1..6))
    dice
  end

  def choose_die!(user, value)
    ensure_turn!(user)
    raise Error, "сначала бросьте кубики" unless dice_rolled?
    raise Error, "на кубиках нет значения #{value}" unless dice.include?(value)

    update!(chosen_die: value)
    allowed_piece
  end

  def record_move!(user:, from:, to:, piece:, san:, fen_after:, captured: nil, spent_seconds: 0)
    ensure_turn!(user)
    raise Error, "сначала бросьте кубики и выберите один из них" if chosen_die.nil?

    color = turn
    remaining = seconds_left(color) - spent_seconds
    if remaining <= 0
      timeout!(color)
      return
    end

    transaction do
      move = moves.create!(
        player: user, ply: moves.count + 1, color: color, piece: piece, from_square: from, to_square: to,
        san: san, captured: captured, die_a: dice_a, die_b: dice_b, die_used: chosen_die,
        fen_after: fen_after, spent_seconds: spent_seconds
      )
      update!(
        fen: fen_after, turn: opposite(color), dice_a: nil, dice_b: nil, chosen_die: nil, draw_offered_by: nil,
        "#{color}_seconds_left" => remaining + increment_seconds
      )
      move
    end
  end

  def offer_draw!(user)
    ensure_participant!(user)
    update!(draw_offered_by: color_of(user))
  end

  def accept_draw!(user)
    ensure_participant!(user)
    raise Error, "ничью никто не предлагал" if draw_offered_by.blank?
    raise Error, "нельзя принять собственное предложение" if draw_offered_by == color_of(user)

    finish!(result: "draw", reason: "agreement")
  end

  def resign!(user)
    ensure_participant!(user)
    finish!(result: "#{opposite(color_of(user))}_win", reason: "resignation")
  end

  def timeout!(color)
    ensure_active!
    update!("#{color}_seconds_left" => 0)
    finish!(result: "#{opposite(color)}_win", reason: "timeout")
  end

  def finish!(result:, reason:)
    ensure_active!

    transaction do
      assign_attributes(
        status: "finished", result: result, end_reason: reason, finished_at: Time.current,
        dice_a: nil, dice_b: nil, chosen_die: nil, draw_offered_by: nil
      )
      validate!
      assign_attributes(apply_rating_changes) if rated?
      save!
    end
  end

  def winner
    case result
    when "white_win" then white_player
    when "black_win" then black_player
    end
  end

  def outcome_for(user)
    color = color_of(user)
    return unless finished? && color

    if result == "draw"
      "draw"
    elsif result == "#{color}_win"
      "win"
    else
      "loss"
    end
  end

  private

  def opposite(color)
    color == "white" ? "black" : "white"
  end

  def free_seat
    white_player_id.nil? ? :white_player : :black_player
  end

  def start_clocks
    self.white_seconds_left = initial_seconds
    self.black_seconds_left = initial_seconds
  end

  def ensure_active!
    raise Error, "партия не идёт" unless active?
  end

  def ensure_participant!(user)
    ensure_active!
    raise Error, "вы не участвуете в этой партии" unless participant?(user)
  end

  def ensure_turn!(user)
    ensure_participant!(user)
    raise Error, "сейчас не ваш ход" unless my_turn?(user)
  end

  def apply_rating_changes
    white_score = { "white_win" => 1.0, "black_win" => 0.0, "draw" => 0.5 }.fetch(result)
    white_delta = EloRating.delta(white_player.rating, black_player.rating, white_score)
    black_delta = EloRating.delta(black_player.rating, white_player.rating, 1 - white_score)

    {
      white_rating_delta: white_player.apply_rating_change!(white_delta),
      black_rating_delta: black_player.apply_rating_change!(black_delta)
    }
  end

  def player_present
    errors.add(:base, :no_players) if white_player_id.nil? && black_player_id.nil?
  end

  def players_differ
    errors.add(:black_player, :same_as_white) if white_player_id.present? && white_player_id == black_player_id
  end

  def opponent_present_once_started
    return if waiting?

    errors.add(:base, :opponent_missing) if white_player_id.nil? || black_player_id.nil?
  end

  def result_matches_status
    if finished?
      errors.add(:result, :blank) if result.blank?
      errors.add(:end_reason, :blank) if end_reason.blank?
    else
      errors.add(:result, :present) if result.present?
    end
  end

  def dice_come_in_pairs
    errors.add(:dice_b, :blank) if dice_a.present? && dice_b.blank?
    errors.add(:dice_a, :blank) if dice_b.present? && dice_a.blank?
  end

  def chosen_die_was_rolled
    return if chosen_die.nil? || dice.include?(chosen_die)

    errors.add(:chosen_die, :not_rolled)
  end
end
