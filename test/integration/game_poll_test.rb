require "test_helper"

class GamePollTest < ActionDispatch::IntegrationTest
  setup do
    @alice = sign_in("alice")
    @bob = sign_in("bob")
    @game = start_game
  end

  def version(session)
    as(session) do
      get state_game_path(@game)
      assert_response :success
      assert_equal "application/json", response.media_type
      response.parsed_body["version"]
    end
  end

  test "the version on the page is the one the state request returns" do
    as(@bob) do
      get game_path(@game)
      on_page = css_select(".game").first["data-version"]

      assert_equal version(@bob), on_page
    end
  end

  test "the version stays the same until something happens in the game" do
    assert_equal version(@alice), version(@bob)
    assert_equal version(@bob), version(@bob)
  end

  test "every step of the game changes the version" do
    seen = [ version(@bob) ]

    rig_dice(1, 2)
    as(@alice) { post roll_game_path(@game) }
    seen << version(@bob)

    as(@alice) { post choose_game_path(@game), params: { die: 1 } }
    seen << version(@bob)

    as(@alice) { post move_game_path(@game), params: { from: "e2", to: "e4" } }
    seen << version(@bob)

    as(@bob) { post offer_draw_game_path(@game) }
    seen << version(@alice)

    as(@bob) { post resign_game_path(@game) }
    seen << version(@alice)

    assert_equal seen.size, seen.uniq.size
  end

  test "a game that was joined changes the version of the waiting creator" do
    waiting = Game.open_for(creator: users(:alice), color: "white")
    before = as(@alice) { get(state_game_path(waiting)) && response.parsed_body["version"] }

    as(@bob) { post join_game_path(waiting) }
    after = as(@alice) { get(state_game_path(waiting)) && response.parsed_body["version"] }

    assert_not_equal before, after
  end

  test "the page keeps checking for changes until the game is over" do
    as(@alice) do
      get game_path(@game)
      assert_select ".game[data-poll-url=?]", state_game_path(@game)
    end

    as(@bob) do
      get game_path(@game)
      assert_select ".game[data-poll-url=?]", state_game_path(@game)
    end

    @game.resign!(users(:bob))
    as(@bob) do
      get game_path(@game)
      assert_select ".game[data-poll-url]", count: 0
    end
  end

  test "an expired clock is noticed by the state request" do
    @game.update!(started_at: 20.minutes.ago)
    reported = version(@bob)

    assert_predicate @game.reload, :finished?
    assert_equal "timeout", @game.end_reason
    assert_match(/\Afinished-/, reported)
  end

  test "the state request needs a signed in user" do
    get state_game_path(@game)
    assert_redirected_to login_path
  end
end
