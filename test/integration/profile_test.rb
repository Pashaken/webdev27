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
      assert_equal "0%", stat("Процент побед")
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
