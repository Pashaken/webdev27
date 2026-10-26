require "test_helper"

class HappyPathTest < ActionDispatch::IntegrationTest
  setup do
    @alice = sign_in("alice")
    @bob = sign_in("bob")
  end

  test "two accounts create, join, play and finish a game by clicking through it" do
    as(@alice) do
      get root_path
      assert_response :success
      assert_select "form[action=?]", games_path
      assert_select ".lobby-section", /Активных партий нет/

      post games_path, params: { color: "white", control: "300+0", rated: "1" }
    end

    game = Game.order(:id).last
    assert_equal "alice", game.white_player.username
    assert_equal 300, game.initial_seconds
    assert game.rated?

    as(@alice) do
      follow_redirect!
      assert_response :success
      assert_select ".alert", /Ждём соперника/
      assert_select ".game[data-poll-url=?]", state_game_path(game)
      assert_select ".game.has-dice", 0
      assert_select "form[action=?]", roll_game_path(game), count: 0
    end

    as(@bob) do
      get root_path
      assert_select ".game-card", /alice/
      assert_select "form[action=?]", join_game_path(game)

      post join_game_path(game)
      follow_redirect!
      assert_response :success
      assert_select ".alert", /Ход соперника/
      assert_select ".game[data-poll-url=?]", state_game_path(game)
      assert_select ".board .square", 64
      assert_select ".game.has-dice > .game-dice .dice-tray"
    end

    assert_predicate game.reload, :active?
    assert_equal "bob", game.black_player.username

    rig_dice(1, 2)
    as(@alice) do
      get game_path(game)
      assert_select ".alert", /бросьте кубики/
      assert_select ".game[data-poll-url=?]", state_game_path(game)
      assert_select ".clock.is-running[data-seconds]", 1
      assert_select ".clock:not(.is-running)[data-seconds]", 0
      post roll_game_path(game)
      follow_redirect!
      assert_select ".alert", /Выберите кубик/
      assert_select ".die[data-value='1']"
      assert_select ".die[data-value='2']"
      assert_select ".die-caption", /Белая пешка/
      assert_select ".die-caption", /Белый конь/

      post choose_game_path(game), params: { die: 1 }
      follow_redirect!
      assert_select ".alert", /белая пешка/
      assert_select ".square.is-clickable", 8
      assert_select ".square[data-square='e2'] a.square-hit"

      get game_path(game, from: "e2")
      assert_select ".square.is-selected[data-square='e2']"
      assert_select ".square.is-target", 2
      assert_select "form[action=?] input[name=to][value=e4]", move_game_path(game)

      post move_game_path(game), params: { from: "e2", to: "e4" }
      follow_redirect!
      assert_select ".move", /e4/
      assert_select ".alert", /Ход соперника/
    end

    as(@bob) do
      get game_path(game)
      assert_select ".alert", /бросьте кубики/
      assert_select ".square[data-square='e4'] .piece[data-piece='wp']"
    end

    as(@alice) do
      get game_path(game)
      assert_select ".clock.is-running[data-seconds]", 1
      assert_select ".player-panel.is-active .player-name", "bob"
    end

    take_turn(@bob, game, dice: [ 2, 6 ], die: 2, from: "g8", to: "f6")
    take_turn(@alice, game, dice: [ 5, 3 ], die: 3, from: "f1", to: "c4")

    as(@alice) do
      get game_path(game)
      assert_select ".move", 3
      assert_select ".square[data-square='c4'] .piece[data-piece='wb']"
      assert_select ".square[data-square='f6'] .piece[data-piece='bn']"
    end

    as(@bob) do
      post resign_game_path(game)
      follow_redirect!
      assert_select ".result-loss .result-title", "Поражение"
      assert_select ".result-reason", "Вы сдались"
      assert_select ".badge", "Рейтинг -16"
    end

    as(@alice) do
      get game_path(game)
      assert_select ".result-win .result-title", "Победа"
      assert_select ".result-reason", "Соперник сдался"
      assert_select ".game.has-dice", 0
      assert_select ".badge", "Рейтинг +16"
      assert_select "form[action=?]", roll_game_path(game), count: 0

      get root_path
      assert_select ".game-card", /Победили белые/
    end

    assert_equal 1516, users(:alice).reload.rating
    assert_equal 1484, users(:bob).reload.rating
    assert_equal "white_win", game.reload.result
    assert_equal "resignation", game.end_reason
  end

  test "a game can end by agreed draw" do
    game = start_game
    as(@alice) { post offer_draw_game_path(game) }

    as(@bob) do
      get game_path(game)
      assert_select ".alert", /предлагает ничью/
      post accept_draw_game_path(game)
      follow_redirect!
      assert_select ".result-draw .result-title", "Ничья"
      assert_select ".result-reason", "Ничья по согласию"
    end

    as(@alice) do
      get game_path(game)
      assert_select ".result-draw .result-title", "Ничья"
    end

    assert_equal "draw", game.reload.result
  end

test "a game ends when the king is captured" do
  game = start_game

  take_turn(@alice, game, dice: [ 1, 4 ], die: 1, from: "f2", to: "f3")
  take_turn(@bob, game, dice: [ 1, 4 ], die: 1, from: "e7", to: "e5")
  take_turn(@alice, game, dice: [ 1, 4 ], die: 1, from: "g2", to: "g4")
  take_turn(@bob, game, dice: [ 5, 4 ], die: 5, from: "d8", to: "h4")
  assert_predicate game.reload, :active?

  take_turn(@alice, game, dice: [ 1, 4 ], die: 1, from: "a2", to: "a3")
  take_turn(@bob, game, dice: [ 5, 4 ], die: 5, from: "h4", to: "e1")

  assert_predicate game.reload, :finished?
  assert_equal "black_win", game.result
  assert_equal "king_captured", game.end_reason

  as(@alice) do
    get game_path(game)
    assert_select ".result-loss .result-title", "Поражение"
    assert_select ".result-reason", "Король взят"
  end

  as(@bob) do
    get game_path(game)
    assert_select ".result-win .result-title", "Победа"
  end
end

test "a player under attack is warned but may play any move" do
  game = start_game

  take_turn(@alice, game, dice: [ 1, 4 ], die: 1, from: "f2", to: "f3")
  take_turn(@bob, game, dice: [ 1, 4 ], die: 1, from: "e7", to: "e5")
  take_turn(@alice, game, dice: [ 6, 6 ], die: 6, from: "e1", to: "f2")
  take_turn(@bob, game, dice: [ 5, 4 ], die: 5, from: "d8", to: "h4")
  assert_predicate game.reload, :active?

  rig_dice(1, 1)
  as(@alice) do
    get game_path(game)
    assert_select ".square.is-check[data-square='f2']"
    assert_select ".alert-warning", /король под боем/

    post roll_game_path(game)
    post choose_game_path(game), params: { die: 1 }
    follow_redirect!
    assert_select ".square.is-clickable", 8

    post move_game_path(game), params: { from: "a2", to: "a3" }
    follow_redirect!
    assert_select ".alert-error", 0
    assert_select ".move", /a3/
  end

  assert_predicate game.reload, :active?
end

  test "a creator can leave a waiting game for the lobby or cancel it" do
    as(@alice) { post games_path, params: { color: "white", control: "600+0" } }
    game = Game.order(:id).last

    as(@alice) do
      get game_path(game)
      assert_select "a[href=?]", root_path, text: "В лобби"
      assert_select "form[action=?] input[name=_method][value=delete]", game_path(game)

      get root_path
      assert_select ".game-card", /Свободно/
    end

    as(@bob) do
      delete game_path(game)
      follow_redirect!
      assert_select ".alert-error", /не участвуете/
    end
    assert Game.exists?(game.id)

    as(@alice) do
      delete game_path(game)
      assert_redirected_to root_path
      follow_redirect!
      assert_select ".alert-success", "Партия отменена."
      assert_select ".lobby-section", /Активных партий нет/
    end
    assert_not Game.exists?(game.id)

    as(@bob) do
      get root_path
      assert_select ".game-card", 0
    end
  end

  test "a started game cannot be cancelled and offers a way back to the lobby" do
    game = start_game

    as(@alice) do
      get game_path(game)
      assert_select "a[href=?]", root_path, text: "В лобби"
      assert_select "form[action=?] input[name=_method][value=delete]", game_path(game), count: 0

      delete game_path(game)
      follow_redirect!
      assert_select ".alert-error", /ждёт соперника/
    end
    assert Game.exists?(game.id)
  end

  test "a roll with no playable piece can be thrown again" do
    game = start_game

    rig_dice(4, 6)
    as(@alice) do
      post roll_game_path(game)
      follow_redirect!
      assert_select ".alert-warning", /Ни одной фигурой нельзя сходить/
      assert_select ".die[disabled]", 2
      assert_select "form[action=?]", reroll_game_path(game)

      rig_dice(1, 3)
      post reroll_game_path(game)
      follow_redirect!
      assert_select ".die[data-value='1']:not([disabled])"
      assert_select ".die[data-value='3'][disabled]"
      assert_select "form[action=?]", reroll_game_path(game), count: 0
    end

    assert_equal [ 1, 3 ], game.reload.dice
    assert_equal 1, game.game_dice_states.count
  end

  test "forbidden actions only show an error and change nothing" do
    game = start_game

    as(@bob) do
      post roll_game_path(game)
      follow_redirect!
      assert_select ".alert-error", /сейчас не ваш ход/
    end

    rig_dice(1, 2)
    as(@alice) do
      post roll_game_path(game)
      post choose_game_path(game), params: { die: 1 }
      post move_game_path(game), params: { from: "e2", to: "e5" }
      follow_redirect!
      assert_select ".alert-error", /так ходить нельзя/
      post move_game_path(game), params: { from: "b1", to: "c3" }
      follow_redirect!
      assert_select ".alert-error", /так ходить нельзя/
    end

    assert_empty game.reload.moves
  end

  test "an outsider watches a game without any controls" do
    game = start_game
    carol = sign_in("carol")

    as(carol) do
      get game_path(game)
      assert_response :success
      assert_select ".alert", /наблюдаете/
      assert_select ".board .square", 64
      assert_select "form[action=?]", roll_game_path(game), count: 0
      assert_select "form[action=?]", resign_game_path(game), count: 0

      post resign_game_path(game)
      follow_redirect!
      assert_select ".alert-error", /не участвуете/
    end

    assert_predicate game.reload, :active?
  end

  test "a player cannot join their own game and a full game is closed" do
    as(@alice) { post games_path, params: { color: "black", control: "600+0" } }
    game = Game.order(:id).last

    as(@alice) do
      post join_game_path(game)
      follow_redirect!
      assert_select ".alert-error", /самим собой/
    end

    as(@bob) { post join_game_path(game) }

    as(sign_in("carol")) do
      post join_game_path(game)
      follow_redirect!
      assert_select ".alert-error", /уже началась/
    end

    assert_equal "bob", game.reload.white_player.username
  end

  test "the lobby and games require login" do
    get root_path
    assert_redirected_to login_path

    get game_path(start_game)
    assert_redirected_to login_path

    post games_path, params: { color: "white", control: "300+0" }
    assert_redirected_to login_path
  end
end
