module UiHelper
  FILES = %w[a b c d e f g h].freeze

  PIECE_LABELS = {
    "wk" => "Белый король", "wq" => "Белый ферзь", "wr" => "Белая ладья",
    "wb" => "Белый слон", "wn" => "Белый конь", "wp" => "Белая пешка",
    "bk" => "Чёрный король", "bq" => "Чёрный ферзь", "br" => "Чёрная ладья",
    "bb" => "Чёрный слон", "bn" => "Чёрный конь", "bp" => "Чёрная пешка"
  }.freeze

  SWATCHES = {
    "Интерфейс" => %w[--bg --surface --surface-muted --border --text --muted --accent --accent-hover],
    "Статусы" => %w[--success-bg --success-border --error-bg --error-border --warning-bg --warning-border --info-bg --info-border],
    "Доска" => %w[--board-light --board-dark --board-selected --board-last-move --board-target --board-check],
    "Фигуры и кубики" => %w[--piece-white --piece-white-edge --piece-black --piece-black-edge --die-face --die-edge --die-pip]
  }.freeze

  def board_squares(flipped: false)
    ranks = flipped ? 1.upto(8).to_a : 8.downto(1).to_a
    files = flipped ? FILES.reverse : FILES
    ranks.product(files).map { |rank, file| "#{file}#{rank}" }
  end

  def square_tone(square)
    (FILES.index(square[0]) + square[1].to_i).odd? ? "dark" : "light"
  end

  def fen_pieces(fen)
    pieces = {}

    fen.split.first.split("/").each_with_index do |row, index|
      file = 0

      row.each_char do |char|
        if char.match?(/\d/)
          file += char.to_i
        else
          color = char == char.upcase ? "w" : "b"
          pieces["#{FILES[file]}#{8 - index}"] = "#{color}#{char.downcase}"
          file += 1
        end
      end
    end

    pieces
  end

  def piece_label(piece)
    PIECE_LABELS.fetch(piece)
  end
end
