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

  test "a new game waits for an opponent with full clocks and the start position" do
    game = Game.open_for(creator: users(:alice), color: "white", initial_seconds: 300, increment_seconds: 5)

    assert_predicate game, :waiting?
    assert_equal "waiting", game.status
    assert_predicate game, :rated?
    assert_equal "white", game.turn
    assert_equal 300, game.initial_seconds
    assert_equal 5, game.increment_seconds
    assert_equal 300, game.seconds_left("white")
    assert_equal 300, game.seconds_left("black")
    assert_equal "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", game.fen
  end

  test "games with the same clock share one time control" do
    first = Game.open_for(creator: users(:alice), initial_seconds: 300)
    second = Game.open_for(creator: users(:bob), initial_seconds: 300)

    assert_equal first.time_control, second.time_control
    assert_equal 1, TimeControl.where(initial_seconds: 300).count
  end

  test "unknown color is rejected" do
    assert_raises(ArgumentError) { Game.open_for(creator: users(:alice), color: "green") }
  end

  test "clock settings outside the limits are rejected" do
    assert_raises(ActiveRecord::RecordInvalid) { Game.open_for(creator: users(:alice), initial_seconds: 30) }
    assert_raises(ActiveRecord::RecordInvalid) { Game.open_for(creator: users(:alice), increment_seconds: 61) }
  end
end

class GameValidationsTest < ActiveSupport::TestCase
  def build_game(**attributes)
    Game.new({ time_control: TimeControl.lookup(600) }.merge(attributes))
  end

  test "a game needs at least one player" do
    game = build_game

    assert_not game.valid?
    assert game.errors.of_kind?(:base, :no_players)
  end

  test "a game cannot have more than two players" do
    game = start_game
    game.game_players.build(user: users(:carol), color: "white")

    assert_not game.valid?
    assert game.errors.of_kind?(:base, :too_many_players)
  end

  test "a started game needs both players" do
    game = Game.open_for(creator: users(:alice), color: "white")
    game.started_at = Time.current

    assert_not game.valid?
    assert game.errors.of_kind?(:base, :opponent_missing)
  end

  test "one user cannot take both seats and a color is taken once" do
    game = Game.open_for(creator: users(:alice), color: "white")

    same_user = GamePlayer.new(game: game, user: users(:alice), color: "black")
    assert_not same_user.valid?
    assert same_user.errors.of_kind?(:user_id, :taken)

    same_color = GamePlayer.new(game: game, user: users(:bob), color: "white")
    assert_not same_color.valid?
    assert same_color.errors.of_kind?(:color, :taken)
  end

  test "a finished game needs result and reason, an unfinished one cannot have a result" do
    finished = start_game
    finished.finished_at = Time.current
    assert_not finished.valid?
    assert finished.errors.of_kind?(:result, :blank)
    assert finished.errors.of_kind?(:end_reason, :blank)

    unfinished = start_game
    unfinished.result = "draw"
    assert_not unfinished.valid?
    assert unfinished.errors.of_kind?(:result, :present)
  end

  test "result and end reason accept only known values" do
    game = start_game

    game.result = "nobody"
    assert_not game.valid?
    assert game.errors.of_kind?(:result, :inclusion)

    game.result = nil
    game.end_reason = "boredom"
    assert_not game.valid?
    assert game.errors.of_kind?(:end_reason, :inclusion)
  end

  test "players are connected to their games" do
    game = start_game

    assert_includes users(:alice).games, game
    assert_includes users(:bob).games, game
    assert_equal [ users(:alice), users(:bob) ].sort_by(&:id), game.users.sort_by(&:id)
    assert_equal 2, game.game_players.size
    assert_empty game.moves
  end
end

class GameJoinTest < ActiveSupport::TestCase
  test "the opponent takes the free seat and the game starts" do
    game = Game.open_for(creator: users(:alice), color: "white")
    game.join!(users(:bob))

    assert_predicate game, :active?
    assert_equal "active", game.status
    assert_equal users(:bob), game.black_player
    assert_not_nil game.started_at
  end

  test "joining a black-seat game gives the white seat" do
    game = Game.open_for(creator: users(:alice), color: "black")
    game.join!(users(:bob))

    assert_equal users(:bob), game.white_player
    assert_equal users(:alice), game.black_player
  end

  test "ratings of both players are frozen when the game starts" do
    users(:alice).update!(rating: 1520)
    game = start_game

    assert_equal 1520, game.game_player_of("white").rating_before
    assert_equal 1500, game.game_player_of("black").rating_before
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

  test "status scopes split games by their stage" do
    waiting = Game.open_for(creator: users(:carol), color: "white")
    active = start_game
    finished = start_game
    finished.resign!(users(:alice))

    assert_includes Game.waiting, waiting
    assert_includes Game.active, active
    assert_includes Game.finished, finished
    assert_not_includes Game.active, finished
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
    assert_equal "white", game.draw_offered_by

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

    assert_equal 16, game.game_player_of("white").rating_delta
    assert_equal(-16, game.game_player_of("black").rating_delta)
    assert_equal 1516, users(:alice).reload.rating
    assert_equal 1484, users(:bob).reload.rating
  end

  test "an unrated game leaves ratings untouched" do
    game = start_game(rated: false)
    game.finish!(result: "white_win", reason: "checkmate")

    assert_nil game.game_player_of("white").rating_delta
    assert_nil game.game_player_of("black").rating_delta
    assert_equal 1500, users(:alice).reload.rating
    assert_equal 1500, users(:bob).reload.rating
  end

  test "the stored rating change is the real one when the floor is hit" do
    users(:alice).update!(rating: 110)
    users(:bob).update!(rating: 110)
    game = start_game
    game.finish!(result: "white_win", reason: "checkmate")

    assert_equal(-10, game.game_player_of("black").rating_delta)
    assert_equal User::MIN_RATING, users(:bob).reload.rating
  end

  test "running out of time loses the game" do
    game = start_game
    game.timeout!("white")

    assert_equal "black_win", game.result
    assert_equal "timeout", game.end_reason
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
