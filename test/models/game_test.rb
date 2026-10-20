require "test_helper"

class GameOpenTest < ActiveSupport::TestCase
  test "creator takes the white seat" do
    game = Game.open_for(creator: users(:alice), color: "white")

    assert_equal users(:alice), game.white_player
    assert_nil game.black_player
  end

  test "creator takes the black seat" do
    game = Game.open_for(creator: users(:alice), color: "black")

    assert_nil game.white_player
    assert_equal users(:alice), game.black_player
  end

  test "random color uses the injected random generator" do
    assert_equal users(:alice), Game.open_for(creator: users(:alice), random: rigged(0)).white_player
    assert_equal users(:alice), Game.open_for(creator: users(:alice), random: rigged(1)).black_player
  end

  test "new game waits for an opponent with full clocks" do
    game = Game.open_for(creator: users(:alice), color: "white", initial_seconds: 300, increment_seconds: 5)

    assert_predicate game, :waiting?
    assert_predicate game, :rated?
    assert_equal "white", game.turn
    assert_equal 300, game.white_seconds_left
    assert_equal 300, game.black_seconds_left
    assert_equal "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", game.fen
  end

  test "unknown color is rejected" do
    assert_raises(ArgumentError) { Game.open_for(creator: users(:alice), color: "green") }
  end
end

class GameValidationsTest < ActiveSupport::TestCase
  def build_game(**attributes)
    Game.new({ white_player: users(:alice) }.merge(attributes))
  end

  test "a game needs at least one player" do
    game = Game.new

    assert_not game.valid?
    assert game.errors.of_kind?(:base, :no_players)
  end

  test "one user cannot take both seats" do
    game = build_game(black_player: users(:alice))

    assert_not game.valid?
    assert game.errors.of_kind?(:black_player, :same_as_white)
  end

  test "a started game needs both players" do
    game = build_game(status: "active")

    assert_not game.valid?
    assert game.errors.of_kind?(:base, :opponent_missing)
  end

  test "clock settings must stay within limits" do
    assert_not build_game(initial_seconds: 30).valid?
    assert_not build_game(initial_seconds: 20_000).valid?
    assert_not build_game(increment_seconds: -1).valid?
    assert_not build_game(increment_seconds: 61).valid?
    assert build_game(initial_seconds: 60, increment_seconds: 60).valid?
  end

  test "dice come in pairs and stay between 1 and 6" do
    lonely = build_game(dice_a: 3)
    assert_not lonely.valid?
    assert lonely.errors.of_kind?(:dice_b, :blank)

    assert_not build_game(dice_a: 7, dice_b: 2).valid?
    assert build_game(dice_a: 6, dice_b: 1).valid?
  end

  test "chosen die has to be one of the rolled dice" do
    game = build_game(dice_a: 2, dice_b: 5, chosen_die: 4)

    assert_not game.valid?
    assert game.errors.of_kind?(:chosen_die, :not_rolled)
  end

  test "a finished game needs result and reason, an unfinished one cannot have a result" do
    finished = build_game(black_player: users(:bob), status: "finished")
    assert_not finished.valid?
    assert finished.errors.of_kind?(:result, :blank)
    assert finished.errors.of_kind?(:end_reason, :blank)

    unfinished = build_game(result: "draw")
    assert_not unfinished.valid?
    assert unfinished.errors.of_kind?(:result, :present)
  end

  test "status, result and end reason accept only known values" do
    assert_not build_game(status: "paused").valid?
    assert_not build_game(result: "nobody").valid?
    assert_not build_game(end_reason: "boredom").valid?
  end

  test "players are connected to their games" do
    game = start_game

    assert_includes users(:alice).games_as_white, game
    assert_includes users(:bob).games_as_black, game
    assert_empty game.moves
  end
end

class GameJoinTest < ActiveSupport::TestCase
  test "the opponent takes the free seat and the game starts" do
    game = Game.open_for(creator: users(:alice), color: "white")
    game.join!(users(:bob))

    assert_predicate game, :active?
    assert_equal users(:bob), game.black_player
    assert_not_nil game.started_at
  end

  test "joining a black-seat game gives the white seat" do
    game = Game.open_for(creator: users(:alice), color: "black")
    game.join!(users(:bob))

    assert_equal users(:bob), game.white_player
    assert_equal users(:alice), game.black_player
  end

  test "the creator cannot join their own game" do
    game = Game.open_for(creator: users(:alice), color: "white")

    assert_raises(Game::Error) { game.join!(users(:alice)) }
    assert_predicate game.reload, :waiting?
  end

  test "a started game cannot be joined by a third player" do
    game = start_game

    assert_raises(Game::Error) { game.join!(users(:carol)) }
  end

  test "colors, opponents and turn are known for every participant" do
    game = start_game

    assert_equal "white", game.color_of(users(:alice))
    assert_equal "black", game.color_of(users(:bob))
    assert_nil game.color_of(users(:carol))
    assert game.participant?(users(:bob))
    assert_not game.participant?(users(:carol))
    assert_equal users(:bob), game.opponent_of(users(:alice))
    assert_equal users(:alice), game.current_player
    assert game.my_turn?(users(:alice))
    assert_not game.my_turn?(users(:bob))
  end
end

class GameFinishTest < ActiveSupport::TestCase
  test "resigning gives the win to the opponent" do
    game = start_game
    game.resign!(users(:alice))

    assert_predicate game, :finished?
    assert_equal "black_win", game.result
    assert_equal "resignation", game.end_reason
    assert_equal users(:bob), game.winner
    assert_not_nil game.finished_at
  end

  test "only participants of a running game can resign" do
    game = start_game

    assert_raises(Game::Error) { game.resign!(users(:carol)) }

    game.resign!(users(:bob))
    assert_raises(Game::Error) { game.resign!(users(:alice)) }
  end

  test "a draw needs an offer from one player and acceptance from the other" do
    game = start_game
    game.offer_draw!(users(:alice))
    game.accept_draw!(users(:bob))

    assert_equal "draw", game.result
    assert_equal "agreement", game.end_reason
    assert_nil game.winner
  end

  test "a draw cannot be accepted without an offer or by the offering player" do
    game = start_game

    assert_raises(Game::Error) { game.accept_draw!(users(:bob)) }

    game.offer_draw!(users(:alice))
    assert_raises(Game::Error) { game.accept_draw!(users(:alice)) }
  end

  test "a rated game changes both ratings with the Elo formula" do
    game = start_game
    game.finish!(result: "white_win", reason: "checkmate")

    assert_equal 16, game.white_rating_delta
    assert_equal(-16, game.black_rating_delta)
    assert_equal 1516, users(:alice).reload.rating
    assert_equal 1484, users(:bob).reload.rating
  end

  test "an unrated game leaves ratings untouched" do
    game = start_game(rated: false)
    game.finish!(result: "white_win", reason: "checkmate")

    assert_nil game.white_rating_delta
    assert_nil game.black_rating_delta
    assert_equal 1500, users(:alice).reload.rating
    assert_equal 1500, users(:bob).reload.rating
  end

  test "the stored rating change is the real one when the floor is hit" do
    users(:alice).update!(rating: 110)
    users(:bob).update!(rating: 110)
    game = start_game
    game.finish!(result: "white_win", reason: "checkmate")

    assert_equal(-10, game.black_rating_delta)
    assert_equal User::MIN_RATING, users(:bob).reload.rating
  end

  test "running out of time loses the game" do
    game = start_game
    game.timeout!("white")

    assert_equal "black_win", game.result
    assert_equal "timeout", game.end_reason
    assert_equal 0, game.white_seconds_left
  end

  test "a game can be finished only once with a valid result" do
    game = start_game

    assert_raises(ActiveRecord::RecordInvalid) { game.finish!(result: "nobody", reason: "checkmate") }
    assert_predicate game.reload, :active?

    game.finish!(result: "draw", reason: "stalemate")
    assert_raises(Game::Error) { game.finish!(result: "draw", reason: "stalemate") }
  end

  test "outcome is reported from the point of view of each player" do
    waiting = Game.open_for(creator: users(:alice), color: "white")
    game = start_game
    game.finish!(result: "white_win", reason: "checkmate")

    assert_equal "win", game.outcome_for(users(:alice))
    assert_equal "loss", game.outcome_for(users(:bob))
    assert_nil game.outcome_for(users(:carol))
    assert_nil waiting.outcome_for(users(:alice))
  end
end
