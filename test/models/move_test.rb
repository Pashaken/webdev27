require "test_helper"

class MoveValidationsTest < ActiveSupport::TestCase
  setup do
    @game = start_game
    @white = @game.game_player_of("white")
    @black = @game.game_player_of("black")
    @roll = @game.game_dice_states.create!(dice_state: DiceState.lookup(1, 5), game_player: @white, ply: 1, chosen_die: 1)
  end

  def build_move(**overrides)
    Move.new({
      game: @game, game_player: @white, game_dice_state: @roll, ply: 1, piece: "p",
      from_square: "e2", to_square: "e4", san: "e4", spent_seconds: 3
    }.merge(overrides))
  end

  test "a regular move is valid" do
    assert build_move.valid?
  end

  test "ply must be positive, unique inside a game and equal to the roll" do
    assert_not build_move(ply: 0).valid?

    wrong = build_move(ply: 2)
    assert_not wrong.valid?
    assert wrong.errors.of_kind?(:ply, :does_not_match_roll)

    build_move.save!
    duplicate = build_move
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:ply, :taken)
  end

  test "squares must exist on the board and differ" do
    assert_not build_move(from_square: "i2").valid?
    assert_not build_move(to_square: "e9").valid?

    same = build_move(to_square: "e2")
    assert_not same.valid?
    assert same.errors.of_kind?(:to_square, :same_as_from)
  end

  test "the piece has to match the chosen die" do
    move = build_move(piece: "n")

    assert_not move.valid?
    assert move.errors.of_kind?(:piece, :does_not_match_die)
  end

  test "the roll must have a chosen die and belong to the same player and game" do
    unchosen = @game.game_dice_states.create!(dice_state: DiceState.lookup(2, 2), game_player: @black, ply: 2)
    move = build_move(game_dice_state: unchosen, game_player: @black, ply: 2, piece: "p")
    assert_not move.valid?
    assert move.errors.of_kind?(:game_dice_state, :no_chosen_die)

    stranger = build_move(game_player: @black)
    assert_not stranger.valid?
    assert stranger.errors.of_kind?(:game_dice_state, :other_player)

    other_game = start_game(white: users(:carol), black: users(:alice))
    foreign_roll = other_game.game_dice_states.create!(
      dice_state: DiceState.lookup(1, 1), game_player: other_game.game_player_of("white"), ply: 1, chosen_die: 1
    )
    foreign = build_move(game_dice_state: foreign_roll)
    assert_not foreign.valid?
    assert foreign.errors.of_kind?(:game_dice_state, :wrong_game)
  end

  test "promotion is required on the last rank and forbidden elsewhere" do
    missing = build_move(from_square: "e7", to_square: "e8")
    assert_not missing.valid?
    assert missing.errors.of_kind?(:promotion, :blank)

    assert build_move(from_square: "e7", to_square: "e8", promotion: "q").valid?
    assert_not build_move(from_square: "e7", to_square: "e8", promotion: "k").valid?

    unwanted = build_move(promotion: "q")
    assert_not unwanted.valid?
    assert unwanted.errors.of_kind?(:promotion, :present)
  end

  test "piece letters and spent time are checked" do
    assert_not build_move(piece: "x").valid?
    assert_not build_move(captured: "z").valid?
    assert_not build_move(spent_seconds: -1).valid?
  end
end

class MoveAssociationsTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @game = start_game(white: @alice, black: users(:bob))
    @move = make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p")
  end

  test "a move belongs to a game, a game player and a roll" do
    assert_equal @game, @move.game
    assert_equal @game.game_player_of("white"), @move.game_player
    assert_equal @game.game_dice_states.first, @move.game_dice_state
  end

  test "color, user and dice come from the related records" do
    assert_equal "white", @move.color
    assert_equal @alice, @move.user
    assert_equal [ 1, 5 ], @move.dice
    assert_includes @alice.moves, @move
  end

  test "a move without its relations is invalid" do
    move = Move.new(ply: 1)
    move.valid?

    assert move.errors.of_kind?(:game, :blank)
    assert move.errors.of_kind?(:game_player, :blank)
    assert move.errors.of_kind?(:game_dice_state, :blank)
  end

  test "moves, rolls and players are deleted together with their game" do
    assert_difference [ "Move.count", "GameDiceState.count" ], -1 do
      assert_difference "GamePlayer.count", -2 do
        @game.destroy
      end
    end
  end

  test "a player with games cannot be deleted" do
    assert_not @alice.destroy
    assert User.exists?(@alice.id)
  end
end

class MoveBusinessLogicTest < ActiveSupport::TestCase
  setup do
    @game = start_game
  end

  test "capture? depends on the captured piece" do
    plain = Move.new(captured: nil)
    taken = Move.new(captured: "q")

    assert_not plain.capture?
    assert taken.capture?
  end

  test "die_used is the die chosen for the roll" do
    roll = @game.game_dice_states.create!(
      dice_state: DiceState.lookup(3, 4), game_player: @game.game_player_of("white"), ply: 1, chosen_die: 4
    )

    assert_equal 4, Move.new(game_dice_state: roll).die_used
    assert_nil Move.new.die_used
  end
end
