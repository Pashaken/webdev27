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
