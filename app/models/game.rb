class Game < ApplicationRecord
  class Error < StandardError; end

  COLORS = %w[white black].freeze
  RESULTS = %w[white_win black_win draw].freeze
  END_REASONS = %w[checkmate resignation timeout stalemate agreement king_captured].freeze
  DICE_PIECES = { 1 => "p", 2 => "n", 3 => "b", 4 => "r", 5 => "q", 6 => "k" }.freeze

  belongs_to :time_control
  has_many :moves, -> { order(:ply) }, dependent: :destroy, inverse_of: :game
  has_many :game_dice_states, -> { order(:ply) }, dependent: :destroy, inverse_of: :game
  has_many :dice_states, through: :game_dice_states
  has_many :draw_offers, dependent: :destroy, inverse_of: :game
  has_many :game_players, dependent: :destroy, inverse_of: :game
  has_many :users, through: :game_players

  cattr_accessor :dice_source, default: Random, instance_accessor: false

  delegate :initial_seconds, :increment_seconds, to: :time_control

  scope :waiting, -> { where(started_at: nil) }
  scope :active, -> { where.not(started_at: nil).where(finished_at: nil) }
  scope :finished, -> { where.not(finished_at: nil) }

  validates :time_control, presence: true
  validates :result, inclusion: { in: RESULTS }, allow_nil: true
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true
  validate :player_present
  validate :player_limit
  validate :opponent_present_once_started
  validate :result_matches_finish

  def self.open_for(creator:, color: "random", random: Random, initial_seconds: 600, increment_seconds: 0, rated: true)
    color = COLORS[random.rand(2)] if color.to_s == "random"
    raise ArgumentError, "неизвестный цвет: #{color}" unless COLORS.include?(color.to_s)

    game = new(time_control: TimeControl.lookup(initial_seconds, increment_seconds), rated: rated)
    game.game_players.build(user: creator, color: color.to_s)
    game.save!
    game
  end

  def join!(user)
    raise Error, "партия уже началась" unless waiting?
    raise Error, "нельзя играть с самим собой" if participant?(user)

    transaction do
      game_players.create!(user: user, color: (COLORS - game_players.map(&:color)).first)
      game_players.each { |player| player.update!(rating_before: player.user.rating) }
      update!(started_at: Time.current)
    end
  end

  def cancel!(user)
    raise Error, "отменить можно только партию, которая ждёт соперника" unless waiting?
    raise Error, "вы не участвуете в этой партии" unless participant?(user)

    destroy!
  end

  def waiting?
    started_at.nil?
  end

  def active?
    started_at.present? && finished_at.nil?
  end

  def finished?
    finished_at.present?
  end

  def status
    if finished?
      "finished"
    elsif active?
      "active"
    else
      "waiting"
    end
  end

  def game_player_for(user)
    return if user.nil? || user.id.nil?

    game_players.find { |player| player.user_id == user.id }
  end

  def game_player_of(color)
    game_players.find { |player| player.color == color }
  end

  def participant?(user)
    game_player_for(user).present?
  end

  def color_of(user)
    game_player_for(user)&.color
  end

  def player_of(color)
    game_player_of(color)&.user
  end

  def white_player
    player_of("white")
  end

  def black_player
    player_of("black")
  end

  def opponent_of(user)
    color = color_of(user)
    player_of(opposite(color)) if color
  end

  def next_ply
    moves.size + 1
  end

  def turn
    moves.size.even? ? "white" : "black"
  end

  def current_player
    player_of(turn)
  end

  def my_turn?(user)
    active? && color_of(user) == turn
  end

  def position
    Position.replay(moves)
  end

  def fen
    position.fen
  end

  def seconds_left(color)
    own_moves = moves.joins(:game_player).where(game_players: { color: color })
    initial_seconds - own_moves.sum(:spent_seconds) + increment_seconds * own_moves.count
  end

  def thinking_seconds(now = Time.current)
    return 0 unless active?

    [ (now - (moves.last&.created_at || started_at)).to_i, 0 ].max
  end

  def clock_left(color, now = Time.current)
    return 0 if end_reason == "timeout" && result == "#{opposite(color)}_win"

    left = seconds_left(color)
    active? && color == turn ? left - thinking_seconds(now) : left
  end

  def expire_clock!
    timeout!(turn) if active? && clock_left(turn) <= 0
  end

  def current_roll
    game_dice_states.find_by(ply: next_ply)
  end

  def dice_rolled?
    current_roll.present?
  end

  def dice
    current_roll&.dice || []
  end

  def chosen_die
    current_roll&.chosen_die
  end

  def allowed_piece
    Game::DICE_PIECES[chosen_die]
  end

  def legal_moves(board = position)
    piece = allowed_piece
    piece ? board.moves_for(turn, piece) : {}
  end

  def playable_dice(board = position)
    dice.uniq.select { |value| board.moves_for(turn, DICE_PIECES[value]).any? }
  end

  def roll_dice!(user, random: self.class.dice_source)
    ensure_turn!(user)
    raise Error, "кубики уже брошены" if dice_rolled?

    dice_state = DiceState.lookup(random.rand(1..6), random.rand(1..6))
    game_dice_states.create!(dice_state: dice_state, game_player: game_player_for(user), ply: next_ply)
    dice_state.dice
  end

  def choose_die!(user, value)
    ensure_turn!(user)
    roll = current_roll
    raise Error, "сначала бросьте кубики" if roll.nil?
    raise Error, "на кубиках нет значения #{value}" unless roll.dice_state.include?(value)

    roll.update!(chosen_die: value)
    roll.piece
  end

  def reroll!(user, random: self.class.dice_source)
    ensure_turn!(user)
    roll = current_roll
    raise Error, "сначала бросьте кубики" if roll.nil?
    raise Error, "есть доступные ходы" if playable_dice.any?

    transaction do
      roll.destroy!
      roll_dice!(user, random: random)
    end
  end

  def play_move!(user:, from:, to:)
    ensure_turn!(user)
    piece = allowed_piece
    raise Error, "сначала выберите кубик" if piece.nil?

    board = position
    raise Error, "так ходить нельзя" unless board.moves_for(turn, piece)[from]&.include?(to)

    promotion = "q" if piece == "p" && %w[1 8].include?(to[1])
    record_move!(
      user: user, from: from, to: to, piece: piece, promotion: promotion,
      san: board.simple_san(from: from, to: to, promotion: promotion), spent_seconds: thinking_seconds
    )
  end

  def record_move!(user:, from:, to:, piece:, san:, promotion: nil, spent_seconds: 0)
    ensure_turn!(user)
    roll = current_roll
    raise Error, "сначала бросьте кубики и выберите один из них" if roll.nil? || !roll.chosen?

    color = turn
    if seconds_left(color) - spent_seconds <= 0
      timeout!(color)
      return
    end

    board = position
    raise Error, "на #{from} нет вашей фигуры #{piece}" unless board.pieces[from] == "#{color[0]}#{piece}"
    raise Error, "на #{to} стоит ваша фигура" if board.pieces[to]&.start_with?(color[0])

    move = moves.create!(
      game_player: roll.game_player, game_dice_state: roll, ply: next_ply, piece: piece, from_square: from,
      to_square: to, promotion: promotion, captured: board.captured_piece(from: from, to: to), san: san,
      spent_seconds: spent_seconds
    )
    finish_if_over!(color)
    move
  end

  def pending_draw_offer
    draw_offers.where(ply: moves.size).order(:id).last
  end

  def draw_offered_by
    pending_draw_offer&.game_player&.color
  end

  def offer_draw!(user)
    ensure_participant!(user)
    draw_offers.find_or_create_by!(game_player: game_player_for(user), ply: moves.size)
  end

  def accept_draw!(user)
    ensure_participant!(user)
    me = game_player_for(user)
    offers = draw_offers.where(ply: moves.size)
    raise Error, "нельзя принять собственное предложение" if offers.where(game_player: me).exists? && !offers.where.not(game_player: me).exists?
    raise Error, "ничью никто не предлагал" unless offers.where.not(game_player: me).exists?

    finish!(result: "draw", reason: "agreement")
  end

  def resign!(user)
    ensure_participant!(user)
    finish!(result: "#{opposite(color_of(user))}_win", reason: "resignation")
  end

  def timeout!(color)
    ensure_active!
    finish!(result: "#{opposite(color)}_win", reason: "timeout")
  end

  def finish!(result:, reason:)
    ensure_active!

    transaction do
      assign_attributes(result: result, end_reason: reason, finished_at: Time.current)
      validate!
      apply_rating_changes if rated?
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

  def finish_if_over!(mover)
    opponent = opposite(mover)
    board = position
    return if board.any_moves?(opponent)

    if board.in_check?(opponent)
      finish!(result: "#{mover}_win", reason: "checkmate")
    else
      finish!(result: "draw", reason: "stalemate")
    end
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
    white = game_player_of("white")
    black = game_player_of("black")
    white_score = { "white_win" => 1.0, "black_win" => 0.0, "draw" => 0.5 }.fetch(result)

    white_delta = EloRating.delta(white.rating_before, black.rating_before, white_score)
    black_delta = EloRating.delta(black.rating_before, white.rating_before, 1 - white_score)

    white.update!(rating_delta: white.user.apply_rating_change!(white_delta))
    black.update!(rating_delta: black.user.apply_rating_change!(black_delta))
  end

  def player_present
    errors.add(:base, :no_players) if game_players.empty?
  end

  def player_limit
    errors.add(:base, :too_many_players) if game_players.size > 2
  end

  def opponent_present_once_started
    errors.add(:base, :opponent_missing) if started_at.present? && game_players.size < 2
  end

  def result_matches_finish
    if finished_at.present?
      errors.add(:result, :blank) if result.blank?
      errors.add(:end_reason, :blank) if end_reason.blank?
    elsif result.present?
      errors.add(:result, :present)
    end
  end
end
