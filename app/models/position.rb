class Position
  FILES = %w[a b c d e f g h].freeze
  START_PLACEMENT = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR".freeze
  CASTLING_BY_SQUARE = { "e1" => "KQ", "a1" => "Q", "h1" => "K", "e8" => "kq", "a8" => "q", "h8" => "k" }.freeze
  KNIGHT_STEPS = [ [ 1, 2 ], [ 2, 1 ], [ 2, -1 ], [ 1, -2 ], [ -1, -2 ], [ -2, -1 ], [ -2, 1 ], [ -1, 2 ] ].freeze
  KING_STEPS = [ [ 1, 0 ], [ 1, 1 ], [ 0, 1 ], [ -1, 1 ], [ -1, 0 ], [ -1, -1 ], [ 0, -1 ], [ 1, -1 ] ].freeze
  DIAGONALS = [ [ 1, 1 ], [ 1, -1 ], [ -1, 1 ], [ -1, -1 ] ].freeze
  STRAIGHTS = [ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ] ].freeze
  CASTLING_ROUTES = {
    "K" => { rook: "h", path: %w[f g], target: "g" },
    "Q" => { rook: "a", path: %w[d c b], target: "c" }
  }.freeze

  attr_reader :pieces, :turn, :en_passant, :halfmove_clock, :fullmove_number

  def self.start
    from_placement(START_PLACEMENT)
  end

  def self.from_placement(placement)
    pieces = {}

    placement.split("/").each_with_index do |row, index|
      file = 0

      row.each_char do |char|
        if char.match?(/\d/)
          file += char.to_i
        else
          pieces["#{FILES[file]}#{8 - index}"] = "#{char == char.upcase ? 'w' : 'b'}#{char.downcase}"
          file += 1
        end
      end
    end

    new(pieces)
  end

  def self.replay(moves)
    moves.each_with_object(start) do |move, position|
      position.apply(from: move.from_square, to: move.to_square, promotion: move.promotion)
    end
  end

  def initialize(pieces)
    @pieces = pieces
    @turn = "white"
    @castling = %w[K Q k q]
    @en_passant = nil
    @halfmove_clock = 0
    @fullmove_number = 1
  end

  def captured_piece(from:, to:)
    target = pieces[to]
    return target[1] if target

    "p" if pieces[from]&.end_with?("p") && from[0] != to[0]
  end

  def moves_from(square)
    piece = pieces[square]
    return [] if piece.nil?

    reachable_squares(square, piece[0])
  end

  def king_square(color)
    pieces.key("#{color[0]}k")
  end

  def in_check?(color)
    square = king_square(color)
    !square.nil? && attacked?(square, color[0] == "w" ? "b" : "w")
  end

  def any_moves?(color)
    pieces.keys.any? { |square| pieces[square].start_with?(color[0]) && moves_from(square).any? }
  end

  def moves_for(color, type)
    wanted = "#{color[0]}#{type}"

    pieces.select { |_, piece| piece == wanted }.keys.each_with_object({}) do |square, result|
      targets = moves_from(square)
      result[square] = targets if targets.any?
    end
  end

  def simple_san(from:, to:, promotion: nil)
    type = pieces[from][1]
    return to[0] == "g" ? "O-O" : "O-O-O" if type == "k" && castling?(from, to)

    capture = captured_piece(from: from, to: to)

    text = type == "p" ? (capture ? from[0] : "") : type.upcase
    text += "x" if capture
    text += to
    text += "=#{promotion.upcase}" if promotion
    text
  end

  def apply(from:, to:, promotion: nil)
    piece = pieces.delete(from)
    raise ArgumentError, "на #{from} нет фигуры" if piece.nil?

    color = piece[0]
    type = piece[1]
    captured = remove_captured(piece, from, to)
    move_rook_for_castling(piece, from, to)

    pieces[to] = promotion ? "#{color}#{promotion}" : piece

    @castling -= CASTLING_BY_SQUARE.values_at(from, to).compact.join.chars
    @en_passant = double_step?(type, from, to) ? "#{from[0]}#{(from[1].to_i + to[1].to_i) / 2}" : nil
    @halfmove_clock = type == "p" || captured ? 0 : halfmove_clock + 1
    @fullmove_number += 1 if color == "b"
    @turn = color == "w" ? "black" : "white"
    self
  end

  def placement
    8.downto(1).map { |rank| rank_placement(rank) }.join("/")
  end

  def fen
    [ placement, turn[0], castling_rights, en_passant || "-", halfmove_clock, fullmove_number ].join(" ")
  end

  def castling_rights
    rights = (%w[K Q k q] & @castling).join
    rights.empty? ? "-" : rights
  end

  private

  def offset(square, file_step, rank_step)
    file = FILES.index(square[0]) + file_step
    rank = square[1].to_i + rank_step

    "#{FILES[file]}#{rank}" if file.between?(0, 7) && rank.between?(1, 8)
  end

  def own?(square, color)
    pieces[square]&.start_with?(color)
  end

  def step_moves(square, color, steps)
    steps.filter_map do |file_step, rank_step|
      target = offset(square, file_step, rank_step)
      target if target && !own?(target, color)
    end
  end

  def slide_moves(square, color, directions)
    directions.flat_map do |file_step, rank_step|
      reached = []
      current = square

      while (current = offset(current, file_step, rank_step))
        break if own?(current, color)

        reached << current
        break if pieces[current]
      end

      reached
    end
  end

  def pawn_moves(square, color)
    direction = color == "w" ? 1 : -1
    start_rank = color == "w" ? 2 : 7
    result = []

    forward = offset(square, 0, direction)
    if forward && pieces[forward].nil?
      result << forward
      double = offset(square, 0, 2 * direction)
      result << double if square[1].to_i == start_rank && double && pieces[double].nil?
    end

    [ -1, 1 ].each do |file_step|
      target = offset(square, file_step, direction)
      next unless target

      enemy = pieces[target] && !own?(target, color)
      passing = target == en_passant && turn[0] == color
      result << target if enemy || passing
    end

    result
  end

  def remove_captured(piece, from, to)
    return pieces[to] if pieces[to]
    return unless piece.end_with?("p") && from[0] != to[0]

    pieces.delete("#{to[0]}#{from[1]}")
  end

  def reachable_squares(square, color)
    case pieces[square][1]
    when "p" then pawn_moves(square, color)
    when "n" then step_moves(square, color, KNIGHT_STEPS)
    when "k" then step_moves(square, color, KING_STEPS) + castling_moves(square, color)
    when "b" then slide_moves(square, color, DIAGONALS)
    when "r" then slide_moves(square, color, STRAIGHTS)
    when "q" then slide_moves(square, color, DIAGONALS + STRAIGHTS)
    else []
    end
  end

  def attacked?(square, by)
    pawn_rank = by == "w" ? -1 : 1

    [ -1, 1 ].any? { |file_step| pieces[offset(square, file_step, pawn_rank)] == "#{by}p" } ||
      KNIGHT_STEPS.any? { |file_step, rank_step| pieces[offset(square, file_step, rank_step)] == "#{by}n" } ||
      KING_STEPS.any? { |file_step, rank_step| pieces[offset(square, file_step, rank_step)] == "#{by}k" } ||
      slider_attacks?(square, by, DIAGONALS, "b") ||
      slider_attacks?(square, by, STRAIGHTS, "r")
  end

  def slider_attacks?(square, by, directions, type)
    directions.any? do |file_step, rank_step|
      current = offset(square, file_step, rank_step)
      current = offset(current, file_step, rank_step) while current && pieces[current].nil?

      current && [ "#{by}#{type}", "#{by}q" ].include?(pieces[current])
    end
  end

  def castling_moves(square, color)
    rank = color == "w" ? "1" : "8"
    return [] unless square == "e#{rank}"

    CASTLING_ROUTES.filter_map do |right, route|
      held = color == "w" ? right : right.downcase
      next unless @castling.include?(held) && pieces["#{route[:rook]}#{rank}"] == "#{color}r"
      next unless route[:path].all? { |file| pieces["#{file}#{rank}"].nil? }

      "#{route[:target]}#{rank}"
    end
  end

  def castling?(from, to)
    (FILES.index(to[0]) - FILES.index(from[0])).abs == 2
  end

  def move_rook_for_castling(piece, from, to)
    return unless piece.end_with?("k") && castling?(from, to)

    rank = from[1]
    rook_from, rook_to = to[0] == "g" ? [ "h#{rank}", "f#{rank}" ] : [ "a#{rank}", "d#{rank}" ]
    rook = pieces.delete(rook_from)
    pieces[rook_to] = rook if rook
  end

  def double_step?(type, from, to)
    type == "p" && (from[1].to_i - to[1].to_i).abs == 2
  end

  def rank_placement(rank)
    row = +""
    empty = 0

    FILES.each do |file|
      piece = pieces["#{file}#{rank}"]

      if piece
        row << empty.to_s if empty.positive?
        empty = 0
        row << (piece[0] == "w" ? piece[1].upcase : piece[1])
      else
        empty += 1
      end
    end

    row << empty.to_s if empty.positive?
    row
  end
end
