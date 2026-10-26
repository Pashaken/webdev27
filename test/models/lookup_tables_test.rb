require "test_helper"

class TimeControlTest < ActiveSupport::TestCase
  test "clock values must stay within limits" do
    assert TimeControl.new(initial_seconds: 600, increment_seconds: 5).valid?
    assert_not TimeControl.new(initial_seconds: 59).valid?
    assert_not TimeControl.new(initial_seconds: 10_801).valid?
    assert_not TimeControl.new(initial_seconds: 600, increment_seconds: -1).valid?
    assert_not TimeControl.new(initial_seconds: 600, increment_seconds: 61).valid?
  end

  test "the same pair of values is stored only once" do
    TimeControl.create!(initial_seconds: 600, increment_seconds: 5)
    duplicate = TimeControl.new(initial_seconds: 600, increment_seconds: 5)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:initial_seconds, :taken)
  end

  test "lookup reuses an existing record instead of creating a new one" do
    first = TimeControl.lookup(900, 10)

    assert_no_difference "TimeControl.count" do
      assert_equal first, TimeControl.lookup(900, 10)
    end
  end

  test "label is short and readable" do
    assert_equal "10 мин", TimeControl.lookup(600).label
    assert_equal "15 + 10", TimeControl.lookup(900, 10).label
  end

  test "a time control used by a game cannot be deleted" do
    game = Game.open_for(creator: users(:alice), initial_seconds: 420)

    assert_not game.time_control.destroy
    assert TimeControl.exists?(game.time_control_id)
  end
end

class DiceStateTest < ActiveSupport::TestCase
  test "both dice stay between 1 and 6" do
    assert DiceState.new(first_die: 1, second_die: 6).valid?
    assert_not DiceState.new(first_die: 0, second_die: 3).valid?
    assert_not DiceState.new(first_die: 3, second_die: 7).valid?
  end

  test "a combination is stored only once" do
    DiceState.create!(first_die: 2, second_die: 5)
    duplicate = DiceState.new(first_die: 2, second_die: 5)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:first_die, :taken)
    assert DiceState.new(first_die: 5, second_die: 2).valid?
  end

  test "lookup reuses an existing combination" do
    first = DiceState.lookup(4, 4)

    assert_no_difference "DiceState.count" do
      assert_equal first, DiceState.lookup(4, 4)
    end
  end

  test "dice and include? describe the combination" do
    state = DiceState.lookup(2, 5)

    assert_equal [ 2, 5 ], state.dice
    assert state.include?(5)
    assert_not state.include?(3)
  end
end

class GameDiceStateTest < ActiveSupport::TestCase
  setup do
    @game = start_game
    @white = @game.game_player_of("white")
  end

  def build_roll(**overrides)
    GameDiceState.new({ game: @game, dice_state: DiceState.lookup(2, 5), game_player: @white, ply: 1 }.merge(overrides))
  end

  test "a roll links a game, a combination of dice and the player who rolled" do
    roll = build_roll
    roll.save!

    assert_equal @game, roll.game
    assert_equal [ 2, 5 ], roll.dice
    assert_equal @white, roll.game_player
    assert_includes @game.dice_states, roll.dice_state
    assert_not roll.chosen?
  end

  test "the chosen die has to be one of the rolled dice" do
    roll = build_roll(chosen_die: 3)

    assert_not roll.valid?
    assert roll.errors.of_kind?(:chosen_die, :not_rolled)

    roll.chosen_die = 5
    assert roll.valid?
    assert_equal "q", roll.piece
  end

  test "ply is positive and unique inside a game" do
    assert_not build_roll(ply: 0).valid?

    build_roll.save!
    duplicate = build_roll(dice_state: DiceState.lookup(1, 1))
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:ply, :taken)
  end

  test "the player has to belong to the same game" do
    other_game = start_game(white: users(:carol), black: users(:alice))
    roll = build_roll(game_player: other_game.game_player_of("white"))

    assert_not roll.valid?
    assert roll.errors.of_kind?(:game_player, :wrong_game)
  end
end
