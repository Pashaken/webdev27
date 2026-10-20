require "test_helper"

class MoveValidationsTest < ActiveSupport::TestCase
  setup do
    @game = start_game
  end

  def build_move(**overrides)
    Move.new({
      game: @game, player: users(:alice), ply: 1, color: "white", piece: "p",
      from_square: "e2", to_square: "e4", san: "e4", die_a: 1, die_b: 5, die_used: 1,
      fen_after: "fen", spent_seconds: 3
    }.merge(overrides))
  end

  test "a regular move is valid" do
    assert build_move.valid?
  end

  test "ply must be a positive number and unique inside a game" do
    assert_not build_move(ply: 0).valid?

    build_move.save!
    duplicate = build_move(ply: 1)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:ply, :taken)
    assert build_move(ply: 2).valid?
  end

  test "squares must exist on the board and differ" do
    assert_not build_move(from_square: "i2").valid?
    assert_not build_move(to_square: "e9").valid?

    same = build_move(to_square: "e2")
    assert_not same.valid?
    assert same.errors.of_kind?(:to_square, :same_as_from)
  end

  test "the used die has to be one of the rolled dice" do
    move = build_move(die_used: 3)

    assert_not move.valid?
    assert move.errors.of_kind?(:die_used, :not_rolled)
  end

  test "the piece has to match the die" do
    move = build_move(piece: "n")

    assert_not move.valid?
    assert move.errors.of_kind?(:piece, :does_not_match_die)
    assert build_move(piece: "q", die_used: 5).valid?
  end

  test "piece letters, color and spent time are checked" do
    assert_not build_move(piece: "x").valid?
    assert_not build_move(captured: "z").valid?
    assert_not build_move(color: "green").valid?
    assert_not build_move(spent_seconds: -1).valid?
  end
end

class MoveAssociationsTest < ActiveSupport::TestCase
  setup do
    @game = start_game
  end

  def create_move(ply)
    @game.moves.create!(
      player: users(:alice), ply: ply, color: "white", piece: "p", from_square: "e2", to_square: "e4",
      san: "e4", die_a: 1, die_b: 5, die_used: 1, fen_after: "fen"
    )
  end

  test "a move belongs to a game and a player" do
    move = create_move(1)

    assert_equal @game, move.game
    assert_equal users(:alice), move.player
    assert_includes users(:alice).moves, move
  end

  test "a move without a game or player is invalid" do
    move = Move.new(ply: 1)
    move.valid?

    assert move.errors.of_kind?(:game, :blank)
    assert move.errors.of_kind?(:player, :blank)
  end

  test "a game returns its moves ordered by ply" do
    create_move(2)
    create_move(1)

    assert_equal [ 1, 2 ], @game.moves.map(&:ply)
  end

  test "moves are deleted together with their game" do
    create_move(1)
    create_move(2)

    assert_difference "Move.count", -2 do
      @game.destroy
    end
  end

  test "a player with moves cannot be deleted" do
    create_move(1)

    assert_not users(:alice).destroy
    assert User.exists?(users(:alice).id)
  end
end

class MoveBusinessLogicTest < ActiveSupport::TestCase
  setup do
    @move = Move.new(die_a: 2, die_b: 6, die_used: 6, piece: "k")
  end

  test "dice returns both rolled values" do
    assert_equal [ 2, 6 ], @move.dice
  end

  test "capture? depends on the captured piece" do
    assert_not @move.capture?

    @move.captured = "q"
    assert @move.capture?
  end
end
