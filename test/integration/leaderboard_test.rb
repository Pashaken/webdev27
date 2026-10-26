require "test_helper"

class LeaderboardTest < ActionDispatch::IntegrationTest
  setup do
    @alice = sign_in("alice")
  end

  def names
    css_select("tbody tr").map { |row| row.at_css("a").text }
  end

  def numbers(name)
    row = css_select("tbody tr").find { |element| element.at_css("a").text == name }
    row.css("td").map { |cell| cell.text.strip }.values_at(0, 2, 3, 4, 5, 6, 7)
  end

  test "players are ordered by rating and numbered" do
    users(:carol).update!(rating: 1600)
    users(:bob).update!(rating: 1400)

    as(@alice) do
      get leaderboard_path
      assert_response :success
      assert_equal %w[carol alice bob], names
      assert_equal %w[1 2 3], css_select("tbody tr").map { |row| row.at_css("td").text.strip }
    end
  end

  test "equal ratings are ordered by name" do
    as(@alice) do
      get leaderboard_path
      assert_equal %w[alice bob carol], names
    end
  end

  test "statistics come from finished games" do
    start_game.resign!(users(:bob))
    drawn = start_game(white: users(:bob), black: users(:alice), rated: false)
    drawn.offer_draw!(users(:bob))
    drawn.accept_draw!(users(:alice))

    as(@alice) do
      get leaderboard_path
      assert_equal %w[1 1516 2 1 0 1 50%], numbers("alice")
      assert_equal %w[2 1500 0 0 0 0 —], numbers("carol")
      assert_equal %w[3 1484 2 0 1 1 0%], numbers("bob")
    end
  end

  test "names lead to profiles and the own row is marked" do
    as(@alice) do
      get leaderboard_path
      assert_select "tbody td a[href=?]", player_path(users(:bob)), text: "bob"
      assert_select "tbody tr.is-me", 1
      assert_select "tbody tr.is-me a[href=?]", player_path(users(:alice))
    end
  end

  test "the navigation links to the lobby, the leaderboard and the profile" do
    as(@alice) do
      get leaderboard_path
      assert_select "a.nav-link[href=?][aria-current=page]", leaderboard_path, text: "Рейтинг"
      assert_select "a.nav-link[href=?]:not([aria-current])", root_path, text: "Лобби"
      assert_select "a.nav-user[href=?]", profile_path

      get root_path
      assert_select "a.nav-link[href=?][aria-current=page]", root_path
    end
  end

  test "the leaderboard requires login" do
    get leaderboard_path
    assert_redirected_to login_path
  end
end
