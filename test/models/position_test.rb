require "test_helper"

class PositionPlacementTest < ActiveSupport::TestCase
  test "the start position has all 32 pieces and the standard fen" do
    position = Position.start

    assert_equal 32, position.pieces.size
    assert_equal "wk", position.pieces["e1"]
    assert_equal "bq", position.pieces["d8"]
    assert_equal "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", position.fen
  end

  test "a position is read from the placement part of a fen" do
    position = Position.from_placement("8/8/8/4k3/8/8/4K3/8")

    assert_equal({ "e5" => "bk", "e2" => "wk" }, position.pieces)
    assert_equal "8/8/8/4k3/8/8/4K3/8", position.placement
  end

  test "captured piece is known before the move is applied" do
    position = Position.from_placement("8/8/8/3p4/4P3/8/8/8")

    assert_equal "p", position.captured_piece(from: "e4", to: "d5")
    assert_nil position.captured_piece(from: "e4", to: "e5")
  end
end

class PositionMovesTest < ActiveSupport::TestCase
  test "a double pawn step sets the en passant square and passes the turn" do
    position = Position.start.apply(from: "e2", to: "e4")

    assert_equal "e3", position.en_passant
    assert_equal "black", position.turn
    assert_equal "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1", position.fen
  end

  test "ordinary moves clear the en passant square and count the clocks" do
    position = Position.start.apply(from: "e2", to: "e4").apply(from: "e7", to: "e5").apply(from: "g1", to: "f3")

    assert_nil position.en_passant
    assert_equal 1, position.halfmove_clock
    assert_equal 2, position.fullmove_number
    assert_equal "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2", position.fen
  end

  test "a capture removes the captured piece" do
    position = Position.from_placement("8/8/8/3p4/4P3/8/8/8").apply(from: "e4", to: "d5")

    assert_equal({ "d5" => "wp" }, position.pieces)
    assert_equal 0, position.halfmove_clock
  end

  test "an en passant capture removes the pawn that made the double step" do
    position = Position.from_placement("8/8/8/3pP3/8/8/8/8")

    assert_equal "p", position.captured_piece(from: "e5", to: "d6")
    position.apply(from: "e5", to: "d6")

    assert_equal({ "d6" => "wp" }, position.pieces)
  end

  test "castling moves the rook too and takes the castling rights away" do
    short = Position.from_placement("r3k2r/8/8/8/8/8/8/R3K2R").apply(from: "e1", to: "g1")
    assert_equal({ "g1" => "wk", "f1" => "wr", "a1" => "wr", "e8" => "bk", "a8" => "br", "h8" => "br" }, short.pieces)
    assert_equal "kq", short.castling_rights

    long = Position.from_placement("r3k2r/8/8/8/8/8/8/R3K2R").apply(from: "e8", to: "c8")
    assert_equal "bk", long.pieces["c8"]
    assert_equal "br", long.pieces["d8"]
    assert_nil long.pieces["a8"]
    assert_equal "KQ", long.castling_rights
  end

  test "moving or capturing a rook removes only the related castling right" do
    moved = Position.from_placement("r3k2r/8/8/8/8/8/8/R3K2R").apply(from: "a1", to: "a2")
    assert_equal "Kkq", moved.castling_rights

    captured = Position.from_placement("r3k2r/8/8/8/8/8/8/R3K2R").apply(from: "a1", to: "a8")
    assert_equal "Kk", captured.castling_rights
  end

  test "a pawn reaching the last rank is replaced by the promoted piece" do
    position = Position.from_placement("8/P7/8/8/8/8/8/8").apply(from: "a7", to: "a8", promotion: "q")

    assert_equal({ "a8" => "wq" }, position.pieces)
  end

  test "moving from an empty square is an error" do
    assert_raises(ArgumentError) { Position.start.apply(from: "e4", to: "e5") }
  end
end

class PositionReplayTest < ActiveSupport::TestCase
  StubMove = Struct.new(:from_square, :to_square, :promotion)

  test "the position is rebuilt from the list of moves" do
    moves = [ StubMove.new("e2", "e4"), StubMove.new("e7", "e5"), StubMove.new("g1", "f3") ]

    assert_equal "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2", Position.replay(moves).fen
  end

  test "an empty list of moves gives the start position" do
    assert_equal Position.start.fen, Position.replay([]).fen
  end

  test "a game derives its position and turn from the saved moves only" do
    game = start_game
    make_move(game, users(:alice), dice: [ 1, 1 ], die: 1, piece: "p", from: "e2", to: "e4")
    make_move(game, users(:bob), dice: [ 1, 1 ], die: 1, piece: "p", from: "e7", to: "e5")

    assert_equal "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2", game.fen
    assert_equal "white", game.turn
    assert_equal game.fen, Game.find(game.id).fen
  end
end

class PositionLegalMovesTest < ActiveSupport::TestCase
  def position(placement)
    Position.from_placement(placement)
  end

  test "pawns and knights are the only pieces that can move from the start position" do
    start = Position.start

    assert_equal %w[e3 e4], start.moves_from("e2")
    assert_equal %w[a3 c3], start.moves_from("b1").sort
    assert_empty start.moves_from("c1")
    assert_empty start.moves_from("a1")
    assert_empty start.moves_from("d1")
    assert_empty start.moves_from("e1")
    assert_empty start.moves_from("e4")

    assert_equal 8, start.moves_for("white", "p").size
    assert_equal %w[b1 g1], start.moves_for("white", "n").keys.sort
    assert_empty start.moves_for("white", "k")
    assert_empty start.moves_for("black", "q")
  end

  test "a pawn is blocked by any piece in front and captures diagonally only" do
    blocked = position("8/8/8/8/3p4/3P4/8/8")
    assert_empty blocked.moves_from("d3")

    capturing = position("8/8/8/2p1p3/3P4/8/8/8")
    assert_equal %w[c5 d5 e5], capturing.moves_from("d4").sort

    black = position("8/3p4/8/8/8/8/8/8")
    assert_equal %w[d5 d6], black.moves_from("d7").sort
  end

  test "a pawn cannot jump over a piece with its double step" do
    assert_empty position("8/8/8/8/8/4p3/4P3/8").moves_from("e2")
    assert_equal %w[e3], position("8/8/8/8/4n3/8/4P3/8").moves_from("e2")
  end

  test "en passant is offered right after the double step" do
    board = position("8/3p4/8/4P3/8/8/8/8")
    assert_not_includes board.moves_from("e5"), "d6"

    board.apply(from: "d7", to: "d5")
    assert_equal "d6", board.en_passant
    assert_includes board.moves_from("e5"), "d6"

    board.apply(from: "e5", to: "e6")
    assert_nil board.en_passant
  end

  test "sliding pieces stop at the first piece and capture an enemy one" do
    board = position("8/8/8/8/3R2p1/8/3P4/8")

    assert_equal %w[a4 b4 c4 d3 d5 d6 d7 d8 e4 f4 g4].sort, board.moves_from("d4").sort

    bishop = position("8/8/5p2/8/3B4/8/1P6/8")
    assert_equal %w[c3 c5 b6 a7 e3 f2 g1 e5 f6].sort, bishop.moves_from("d4").sort
  end

  test "a queen moves like a rook and a bishop together" do
    assert_equal 27, position("8/8/8/8/3Q4/8/8/8").moves_from("d4").size
  end

  test "a knight jumps over pieces but cannot land on its own" do
    assert_equal 8, position("8/8/8/8/3N4/8/8/8").moves_from("d4").size
    assert_equal %w[c2], position("8/8/8/8/8/1P6/PP6/N7").moves_from("a1")
    assert_equal %w[b3 c2], position("8/8/8/8/8/1p6/PP6/N7").moves_from("a1").sort
  end

  test "a king steps to any free or enemy square around it" do
    board = position("8/8/8/8/2pK4/2PP4/8/8")

    assert_equal %w[c4 c5 d5 e3 e4 e5], board.moves_from("d4").sort
  end

  test "castling is offered when the way is free and the rights are kept" do
    board = position("r3k2r/8/8/8/8/8/8/R3K2R")

    assert_includes board.moves_from("e1"), "g1"
    assert_includes board.moves_from("e1"), "c1"

    board.apply(from: "e1", to: "g1")
    assert_equal "R4RK1", board.placement.split("/").last
  end

  test "castling is not offered through pieces, without a rook or after the rights are gone" do
    assert_not_includes position("8/8/8/8/8/8/8/R2QK2R").moves_from("e1"), "c1"
    assert_includes position("8/8/8/8/8/8/8/R2QK2R").moves_from("e1"), "g1"
    assert_not_includes position("8/8/8/8/8/8/8/4K1NR").moves_from("e1"), "g1"
    assert_not_includes position("8/8/8/8/8/8/8/4K3").moves_from("e1"), "g1"

    moved = position("r3k2r/8/8/8/8/8/8/R3K2R").apply(from: "h1", to: "h2").apply(from: "h8", to: "h7")
    assert_not_includes moved.moves_from("e1"), "g1"
    assert_includes moved.moves_from("e1"), "c1"
  end

  test "a simple notation is built from the position before the move" do
    start = Position.start
    assert_equal "e4", start.simple_san(from: "e2", to: "e4")
    assert_equal "Nf3", start.simple_san(from: "g1", to: "f3")

    capture = position("8/8/8/3p4/4P3/8/8/8")
    assert_equal "exd5", capture.simple_san(from: "e4", to: "d5")

    assert_equal "Bxb7", position("8/1p6/8/8/4B3/8/8/8").simple_san(from: "e4", to: "b7")
    assert_equal "e8=Q", position("8/4P3/8/8/8/8/8/8").simple_san(from: "e7", to: "e8", promotion: "q")
    assert_equal "O-O", position("8/8/8/8/8/8/8/4K2R").simple_san(from: "e1", to: "g1")
    assert_equal "O-O-O", position("8/8/8/8/8/8/8/R3K3").simple_san(from: "e1", to: "c1")
  end
end

class PositionAttackTest < ActiveSupport::TestCase
  def position(placement)
    Position.from_placement(placement)
  end

  test "a king is under attack from every kind of piece" do
    assert position("4k3/8/8/8/8/8/8/4R3").in_check?("black")
    assert position("4k3/8/8/8/B7/8/8/4K3").in_check?("black")
    assert position("4k3/8/3N4/8/8/8/8/4K3").in_check?("black")
    assert position("4k3/3P4/8/8/8/8/8/4K3").in_check?("black")
    assert position("4k3/4Q3/8/8/8/8/8/4K3").in_check?("black")
    assert position("8/8/8/8/8/8/4k3/4K3").in_check?("white")
    assert position("8/8/8/8/8/3p4/4K3/8").in_check?("white")
  end

  test "a blocked line and a pawn straight ahead are not an attack" do
    assert_not position("4k3/4p3/8/8/8/8/8/4R3").in_check?("black")
    assert_not position("4k3/4P3/8/8/8/8/8/4K3").in_check?("black")
    assert_not position("4K3/8/8/8/8/8/8/8").in_check?("white")
    assert_not position("8/8/8/8/8/8/8/8").in_check?("white")
  end

  test "an attack does not limit the moves because the game is won by taking the king" do
    stepping = position("8/8/8/8/8/5r2/8/4K3")
    assert_equal %w[d1 d2 e2 f1 f2], stepping.moves_from("e1").sort

    pinned = position("4k3/4r3/8/8/8/8/4B3/4K3")
    assert_not_empty pinned.moves_from("e2")

    castling = position("4k3/8/8/8/4r3/8/8/R3K2R")
    assert_includes castling.moves_from("e1"), "g1"
    assert_includes castling.moves_from("e1"), "c1"
  end

  test "the king can be found and taken like any other piece" do
    board = position("4k3/8/8/8/8/8/4R3/4K3")

    assert_equal "e8", board.king_square("black")
    assert_equal "k", board.captured_piece(from: "e2", to: "e8").then { |piece| piece }
    board.apply(from: "e2", to: "e8")
    assert_nil board.king_square("black")
  end

  test "a side is without moves when all its pieces are blocked" do
    board = position("8/p7/P7/8/8/8/8/4K3")

    assert_not board.any_moves?("black")
    assert board.any_moves?("white")
    assert Position.start.any_moves?("white")
  end
end
