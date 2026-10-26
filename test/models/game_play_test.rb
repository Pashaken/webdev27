require "test_helper"

class GameDiceTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @game = start_game(white: @alice, black: @bob)
  end

  test "rolling stores the roll of the current move" do
    assert_equal [ 2, 5 ], @game.roll_dice!(@alice, random: rigged(2, 5))
    assert_equal [ 2, 5 ], @game.dice
    assert_predicate @game, :dice_rolled?
    assert_equal 1, @game.current_roll.ply
    assert_equal @game.game_player_of("white"), @game.current_roll.game_player
  end

  test "the same combination of dice is stored once and shared by games" do
    other = start_game(white: users(:carol), black: @bob)
    @game.roll_dice!(@alice, random: rigged(3, 4))
    other.roll_dice!(users(:carol), random: rigged(3, 4))

    assert_equal 1, DiceState.where(first_die: 3, second_die: 4).count
    assert_equal 2, DiceState.find_by(first_die: 3, second_die: 4).games.count
  end

  test "real random produces values from 1 to 6" do
    rolled = @game.roll_dice!(@alice)

    assert_equal 2, rolled.size
    assert rolled.all? { |value| (1..6).cover?(value) }
  end

  test "only the player to move can roll, and only once" do
    assert_raises(Game::Error) { @game.roll_dice!(@bob) }

    @game.roll_dice!(@alice, random: rigged(1, 2))
    assert_raises(Game::Error) { @game.roll_dice!(@alice) }
  end

  test "dice cannot be rolled before the opponent joins" do
    waiting = Game.open_for(creator: @alice, color: "white")

    assert_raises(Game::Error) { waiting.roll_dice!(@alice) }
  end

  test "choosing a die returns the piece it allows to move" do
    @game.roll_dice!(@alice, random: rigged(2, 5))

    assert_nil @game.allowed_piece
    assert_equal "n", @game.choose_die!(@alice, 2)
    assert_equal 2, @game.chosen_die
    assert_equal "n", @game.allowed_piece
  end

  test "every die value maps to its own piece" do
    assert_equal %w[p n b r q k], (1..6).map { |value| Game::DICE_PIECES[value] }
  end

  test "a die that was not rolled cannot be chosen" do
    @game.roll_dice!(@alice, random: rigged(2, 5))

    assert_raises(Game::Error) { @game.choose_die!(@alice, 4) }
    assert_nil @game.chosen_die
  end

  test "a die cannot be chosen before the roll or by the opponent" do
    assert_raises(Game::Error) { @game.choose_die!(@alice, 3) }

    @game.roll_dice!(@alice, random: rigged(3, 4))
    assert_raises(Game::Error) { @game.choose_die!(@bob, 3) }
  end
end

class GameMovesTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @game = start_game(white: @alice, black: @bob)
  end

  test "a move is saved together with the roll it was made with" do
    move = make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p")

    assert_equal 1, move.ply
    assert_equal "white", move.color
    assert_equal [ 1, 5 ], move.dice
    assert_equal 1, move.die_used
    assert_equal @alice, move.user
    assert_equal move, @game.game_dice_states.find_by(ply: 1).move
  end

  test "after a move the turn passes and the next roll is empty" do
    make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p")

    assert_equal "black", @game.turn
    assert_equal [], @game.dice
    assert_nil @game.chosen_die
    assert @game.my_turn?(@bob)
  end

  test "moves are numbered in the order they were played" do
    make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p")
    reply = make_move(@game, @bob, dice: [ 2, 2 ], die: 2, piece: "n", from: "g8", to: "f6")

    assert_equal 2, reply.ply
    assert_equal "black", reply.color
    assert_equal [ 1, 2 ], @game.moves.map(&:ply)
  end

  test "a move needs a chosen die" do
    @game.roll_dice!(@alice, random: rigged(1, 5))

    assert_raises(Game::Error) do
      @game.record_move!(user: @alice, from: "e2", to: "e4", piece: "p", san: "e4")
    end
  end

  test "only the player to move can make a move" do
    @game.roll_dice!(@alice, random: rigged(1, 5))
    @game.choose_die!(@alice, 1)

    assert_raises(Game::Error) do
      @game.record_move!(user: @bob, from: "e7", to: "e5", piece: "p", san: "e5")
    end
  end

  test "the moved piece has to match the chosen die and nothing changes otherwise" do
    @game.roll_dice!(@alice, random: rigged(2, 5))
    @game.choose_die!(@alice, 2)

    assert_raises(ActiveRecord::RecordInvalid) do
      @game.record_move!(user: @alice, from: "e2", to: "e4", piece: "p", san: "e4")
    end

    assert_equal "white", @game.turn
    assert_equal 2, @game.chosen_die
    assert_equal 0, @game.moves.count
  end

  test "the piece has to stand on the starting square and cannot take its own piece" do
    @game.roll_dice!(@alice, random: rigged(2, 4))
    @game.choose_die!(@alice, 2)
    assert_raises(Game::Error) do
      @game.record_move!(user: @alice, from: "e3", to: "f5", piece: "n", san: "Nf5")
    end

    @game.choose_die!(@alice, 4)
    assert_raises(Game::Error) do
      @game.record_move!(user: @alice, from: "a1", to: "a2", piece: "r", san: "Ra2")
    end
  end

  test "captures are derived from the position" do
    make_move(@game, @alice, dice: [ 1, 1 ], die: 1, piece: "p", from: "e2", to: "e4")
    make_move(@game, @bob, dice: [ 1, 1 ], die: 1, piece: "p", from: "d7", to: "d5")
    capture = make_move(@game, @alice, dice: [ 1, 1 ], die: 1, piece: "p", from: "e4", to: "d5")

    assert_predicate capture, :capture?
    assert_equal "p", capture.captured
    assert_equal "wp", @game.position.pieces["d5"]
  end

  test "a pending draw offer disappears after a move" do
    @game.offer_draw!(@bob)
    assert_equal "black", @game.draw_offered_by

    make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p")

    assert_nil @game.draw_offered_by
  end
end

class GameClockTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @game = start_game(white: @alice, black: @bob, initial_seconds: 300, increment_seconds: 5)
  end

  test "spent time is subtracted and the increment is added" do
    make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p", spent_seconds: 12)

    assert_equal 293, @game.seconds_left("white")
    assert_equal 300, @game.seconds_left("black")
  end

  test "the clock is derived from all moves of a player" do
    make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p", spent_seconds: 10)
    make_move(@game, @bob, dice: [ 1, 1 ], die: 1, piece: "p", from: "e7", to: "e5", spent_seconds: 4)
    make_move(@game, @alice, dice: [ 2, 2 ], die: 2, piece: "n", from: "g1", to: "f3", spent_seconds: 20)

    assert_equal 280, @game.seconds_left("white")
    assert_equal 301, @game.seconds_left("black")
  end

  test "spending more time than left ends the game and the move is not recorded" do
    result = make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p", spent_seconds: 301)

    assert_nil result
    assert_predicate @game, :finished?
    assert_equal "black_win", @game.result
    assert_equal "timeout", @game.end_reason
    assert_equal 0, @game.moves.count
  end

  test "spending exactly the remaining time also loses" do
    make_move(@game, @alice, dice: [ 1, 5 ], die: 1, piece: "p", spent_seconds: 300)

    assert_equal "timeout", @game.end_reason
  end

  test "the opponent wins when the other clock runs out" do
    @game.timeout!("black")

    assert_equal "white_win", @game.result
    assert_equal users(:alice), @game.winner
  end
end

class GameLegalMovesTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @game = start_game(white: @alice, black: @bob)
  end

  test "legal moves depend on the chosen die" do
    assert_empty @game.legal_moves

    @game.roll_dice!(@alice, random: rigged(1, 2))
    assert_empty @game.legal_moves

    @game.choose_die!(@alice, 2)
    assert_equal %w[b1 g1], @game.legal_moves.keys.sort
    assert_equal %w[a3 c3], @game.legal_moves["b1"].sort
  end

test "playable dice are the values whose piece can move" do
  @game.roll_dice!(@alice, random: rigged(1, 6))
  assert_equal [ 1 ], @game.playable_dice

  other = start_game(white: users(:carol), black: @bob)
  other.roll_dice!(users(:carol), random: rigged(2, 2))
  assert_equal [ 2 ], other.playable_dice
end

  test "a roll without playable dice can be thrown again" do
    @game.roll_dice!(@alice, random: rigged(4, 6))
    assert_empty @game.playable_dice

    assert_equal [ 1, 3 ], @game.reroll!(@alice, random: rigged(1, 3))
    assert_equal [ 1, 3 ], @game.dice
    assert_equal 1, @game.game_dice_states.count
  end

  test "a roll with playable dice cannot be thrown again" do
    @game.roll_dice!(@alice, random: rigged(1, 6))

    assert_raises(Game::Error) { @game.reroll!(@alice, random: rigged(1, 1)) }
    assert_equal [ 1, 6 ], @game.dice
  end

  test "rolling again needs a roll and the right player" do
    assert_raises(Game::Error) { @game.reroll!(@alice) }

    @game.roll_dice!(@alice, random: rigged(4, 6))
    assert_raises(Game::Error) { @game.reroll!(@bob) }
  end

  test "play_move! uses the chosen piece, writes the notation and promotes to a queen" do
    @game.roll_dice!(@alice, random: rigged(1, 2))
    @game.choose_die!(@alice, 1)
    move = @game.play_move!(user: @alice, from: "e2", to: "e4")

    assert_equal "e4", move.san
    assert_equal "p", move.piece
    assert_equal "black", @game.turn
    assert_equal "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1", @game.fen
  end

  test "play_move! rejects moves that do not follow the rules or the die" do
    assert_raises(Game::Error) { @game.play_move!(user: @alice, from: "e2", to: "e4") }

    @game.roll_dice!(@alice, random: rigged(1, 2))
    assert_raises(Game::Error) { @game.play_move!(user: @alice, from: "e2", to: "e4") }

    @game.choose_die!(@alice, 1)
    assert_raises(Game::Error) { @game.play_move!(user: @alice, from: "e2", to: "e5") }
    assert_raises(Game::Error) { @game.play_move!(user: @alice, from: "b1", to: "c3") }
    assert_raises(Game::Error) { @game.play_move!(user: @alice, from: "e7", to: "e6") }
    assert_raises(Game::Error) { @game.play_move!(user: @bob, from: "e2", to: "e4") }
    assert_empty @game.moves
  end

  test "a pawn reaching the last rank becomes a queen" do
    game = start_game(white: users(:carol), black: @bob)
    plan = [
      [ "carol", "a2", "a4" ], [ "bob", "b7", "b5" ], [ "carol", "a4", "b5" ], [ "bob", "a7", "a6" ],
      [ "carol", "b5", "a6" ], [ "bob", "g8", "f6" ], [ "carol", "a6", "a7" ], [ "bob", "f6", "g8" ],
      [ "carol", "a7", "b8" ]
    ]

    plan.each { |name, from, to| play_move(game, users(name.to_sym), from, to) }

    last = game.moves.last
    assert_equal "q", last.promotion
    assert_equal "axb8=Q", last.san
    assert_equal "n", last.captured
    assert_equal "wq", game.position.pieces["b8"]
  end

  test "a checkmate ends the game with a win" do
    play_move(@game, @alice, "f2", "f3")
    play_move(@game, @bob, "e7", "e5")
    play_move(@game, @alice, "g2", "g4")
    assert_predicate @game, :active?

    move = play_move(@game, @bob, "d8", "h4")

    assert_equal "Qh4", move.san
    assert_predicate @game, :finished?
    assert_equal "black_win", @game.result
    assert_equal "checkmate", @game.end_reason
    assert_equal @bob, @game.winner
    assert_equal 1516, @bob.reload.rating
    assert_equal 1484, @alice.reload.rating
  end

  test "an ordinary check does not end the game" do
    play_move(@game, @alice, "f2", "f3")
    play_move(@game, @bob, "e7", "e5")
    play_move(@game, @alice, "e1", "f2", die: 6)
    play_move(@game, @bob, "d8", "h4")

    assert_predicate @game, :active?
    assert @game.position.in_check?("white")
  end

  test "a move that leaves the own king in check is rejected" do
    play_move(@game, @alice, "f2", "f3")
    play_move(@game, @bob, "e7", "e5")
    play_move(@game, @alice, "e1", "f2", die: 6)
    play_move(@game, @bob, "d8", "h4")

    @game.roll_dice!(@alice, random: rigged(1, 1))
    @game.choose_die!(@alice, 1)

    assert_equal %w[g2], @game.legal_moves.keys
    assert_equal %w[g3], @game.legal_moves["g2"]
    assert_raises(Game::Error) { @game.play_move!(user: @alice, from: "a2", to: "a3") }
    assert_equal "g3", @game.play_move!(user: @alice, from: "g2", to: "g3").to_square
  end

  test "dice that cannot save the king have to be rolled again" do
    play_move(@game, @alice, "f2", "f3")
    play_move(@game, @bob, "e7", "e5")
    play_move(@game, @alice, "e1", "f2", die: 6)
    play_move(@game, @bob, "d8", "h4")

    @game.roll_dice!(@alice, random: rigged(2, 2))
    assert_empty @game.playable_dice

    assert_equal [ 1, 3 ], @game.reroll!(@alice, random: rigged(1, 3))
    assert_equal [ 1 ], @game.playable_dice
  end
end

class GameCancelTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
  end

  test "the creator can cancel a game that waits for an opponent" do
    game = Game.open_for(creator: @alice, color: "white")

    assert_difference [ "Game.count", "GamePlayer.count" ], -1 do
      game.cancel!(@alice)
    end
    assert_not Game.exists?(game.id)
  end

  test "someone else cannot cancel the game" do
    game = Game.open_for(creator: @alice, color: "white")

    assert_raises(Game::Error) { game.cancel!(users(:bob)) }
    assert Game.exists?(game.id)
  end

  test "a game that has started cannot be cancelled" do
    game = start_game(white: @alice, black: users(:bob))

    assert_raises(Game::Error) { game.cancel!(@alice) }
    assert Game.exists?(game.id)
  end
end

class GameRunningClockTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @game = start_game(white: @alice, black: @bob, initial_seconds: 300)
    @game.update!(started_at: Time.utc(2026, 10, 27, 12))
  end

  test "thinking time counts from the start of the game or the last move" do
    travel_to @game.started_at + 40.seconds do
      assert_equal 40, @game.thinking_seconds
      assert_equal 260, @game.clock_left("white")
      assert_equal 300, @game.clock_left("black")
    end
  end

  test "the clock of the player who just moved stops and the other one starts" do
    travel_to @game.started_at + 10.seconds do
      @game.roll_dice!(@alice, random: rigged(1, 2))
      @game.choose_die!(@alice, 1)
      @game.play_move!(user: @alice, from: "e2", to: "e4")
    end

    travel_to @game.started_at + 25.seconds do
      assert_equal 290, @game.clock_left("white")
      assert_equal 285, @game.clock_left("black")
      assert_equal 15, @game.thinking_seconds
    end
  end

  test "the spent time of a move is saved" do
    travel_to @game.started_at + 12.seconds do
      @game.roll_dice!(@alice, random: rigged(1, 2))
      @game.choose_die!(@alice, 1)
      @game.play_move!(user: @alice, from: "e2", to: "e4")
    end

    assert_equal 12, @game.moves.last.spent_seconds
  end

  test "an expired clock ends the game when it is checked" do
    travel_to @game.started_at + 299.seconds do
      @game.expire_clock!
      assert_predicate @game, :active?
    end

    travel_to @game.started_at + 301.seconds do
      @game.expire_clock!
    end

    assert_predicate @game, :finished?
    assert_equal "black_win", @game.result
    assert_equal "timeout", @game.end_reason
    assert_equal 0, @game.clock_left("white")
    assert_equal 300, @game.clock_left("black")
  end

  test "a finished or waiting game has no running clock" do
    waiting = Game.open_for(creator: @alice, color: "white")
    assert_equal 0, waiting.thinking_seconds
    assert_nil waiting.expire_clock!

    @game.resign!(@alice)
    assert_equal 0, @game.thinking_seconds
    assert_nil @game.expire_clock!
  end
end
