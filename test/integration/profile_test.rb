require "test_helper"

class ProfileTest < ActionDispatch::IntegrationTest
  setup do
    @alice = sign_in("alice")
    @bob = sign_in("bob")
  end

  def stat(label)
    css_select(".stat").find { |element| element.at_css(".stat-label").text == label }.at_css(".stat-value").text
  end

  test "a player without games sees empty statistics" do
    as(@alice) do
      get profile_path
      assert_response :success
      assert_select "h1", "alice"
      assert_select ".badge-accent", "Рейтинг 1500"
      assert_equal "0", stat("Партии")
      assert_equal "—", stat("Процент побед")
      assert_equal "1500", stat("Рейтинг")
      assert_select ".profile-section", /Завершённых партий пока нет/
      assert_select "table", 0
    end
  end

  test "the name in the header leads to the own profile" do
    as(@alice) do
      get root_path
      assert_select "a.nav-user[href=?]", profile_path, text: "alice"
    end
  end

  test "statistics and history are built from finished games" do
    game = start_game
    play_move(game, users(:alice), "e2", "e4")
    game.resign!(users(:bob))

    as(@alice) do
      get profile_path
      assert_equal "1", stat("Партии")
      assert_equal "1", stat("Победы")
      assert_equal "0", stat("Поражения")
      assert_equal "100%", stat("Процент побед")
      assert_equal "1516", stat("Рейтинг")

      assert_select "tbody tr", 1
      assert_select "tbody td a[href=?]", player_path(users(:bob)), text: "bob"
      assert_select "tbody .badge-success", "Победа"
      assert_select "tbody td.num", "1"
      assert_select "tbody td.num", "+16"
      assert_select "tbody td a[href=?]", game_path(game), text: "Открыть"
    end

    as(@bob) do
      get profile_path
      assert_equal "1", stat("Поражения")
      assert_equal "0%", stat("Процент побед")
      assert_select "tbody .badge-error", "Поражение"
      assert_select "tbody td.num", "-16"
    end
  end

  test "draws and unrated games are shown in the history" do
    drawn = start_game
    drawn.offer_draw!(users(:alice))
    drawn.accept_draw!(users(:bob))
    start_game(rated: false).resign!(users(:alice))

    as(@alice) do
      get profile_path
      assert_equal "2", stat("Партии")
      assert_equal "1", stat("Ничьи")
      assert_equal "1", stat("Поражения")
      assert_equal "0%", stat("Процент побед")
      assert_select "tbody .badge-warning", "Ничья"
      assert_select "tbody td.num", "не рейтинговая"
    end
  end

  test "another player's profile is open to any signed in user" do
    game = start_game
    game.resign!(users(:bob))

    as(@bob) do
      get player_path(users(:alice))
      assert_response :success
      assert_select "h1", "alice"
      assert_select "tbody .badge-success", "Победа"
      assert_select "tbody td a[href=?]", player_path(users(:bob)), text: "bob"
    end
  end

  test "the history is split into pages with the newest games first" do
    games = Array.new(22) { start_game.tap { |game| game.resign!(users(:bob)) } }

    as(@alice) do
      get profile_path
      assert_select "tbody tr", 20
      assert_select "tbody tr:first-child a[href=?]", game_path(games.last), text: "Открыть"
      assert_select ".pager .caption", "Страница 1"
      assert_select ".pager a[href=?]", player_path(users(:alice), page: 2), text: "Раньше ›"
      assert_select ".pager a", text: "‹ Позже", count: 0

      get player_path(users(:alice), page: 2)
      assert_select "tbody tr", 2
      assert_select "tbody tr:last-child a[href=?]", game_path(games.first), text: "Открыть"
      assert_select ".pager a[href=?]", player_path(users(:alice), page: 1), text: "‹ Позже"
      assert_select ".pager a", text: "Раньше ›", count: 0
    end
  end

  test "a wrong page number falls back to a sensible page" do
    start_game.resign!(users(:bob))

    as(@alice) do
      get player_path(users(:alice), page: "abc")
      assert_response :success
      assert_select "tbody tr", 1

      get player_path(users(:alice), page: -5)
      assert_select "tbody tr", 1

      get player_path(users(:alice), page: "999999999999999999999")
      assert_response :success
      assert_select ".profile-section", /Завершённых партий пока нет/
    end
  end

  test "a finished game of another player can be opened and watched" do
    game = start_game
    play_move(game, users(:alice), "e2", "e4")
    game.resign!(users(:bob))
    carol = sign_in("carol")

    as(carol) do
      get player_path(users(:alice))
      assert_select "tbody td a[href=?]", game_path(game), text: "Открыть"

      get game_path(game)
      assert_response :success
      assert_select ".alert", /Победили белые/
      assert_select ".square[data-square='e4'] .piece[data-piece='wp']"
      assert_select ".move", /e4/
      assert_select ".game.has-dice", 0
      assert_select "form[action=?]", roll_game_path(game), count: 0
    end
  end

  test "players on the game page lead to their profiles" do
    game = start_game

    as(@alice) do
      get game_path(game)
      assert_select ".player-name a[href=?]", player_path(users(:alice)), text: "alice"
      assert_select ".player-name a[href=?]", player_path(users(:bob)), text: "bob"
    end
  end

  test "an unknown player is not found" do
    as(@alice) do
      get player_path(id: 0)
      assert_response :not_found
    end
  end

  test "profiles require login" do
    get profile_path
    assert_redirected_to login_path

    get player_path(users(:alice))
    assert_redirected_to login_path
  end
end
