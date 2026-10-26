class Position
  FILES = %w[a b c d e f g h].freeze
  START_PLACEMENT = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR".freeze
  CASTLING_BY_SQUARE = { "e1" => "KQ", "a1" => "Q", "h1" => "K", "e8" => "kq", "a8" => "q", "h8" => "k" }.freeze

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

  def remove_captured(piece, from, to)
    return pieces[to] if pieces[to]
    return unless piece.end_with?("p") && from[0] != to[0]

    pieces.delete("#{to[0]}#{from[1]}")
  end

  def move_rook_for_castling(piece, from, to)
    return unless piece.end_with?("k") && (FILES.index(to[0]) - FILES.index(from[0])).abs == 2

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
