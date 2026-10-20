require "test_helper"

class UserValidationsTest < ActiveSupport::TestCase
  def build_user(**attributes)
    User.new({ username: "dave", password: "secret123" }.merge(attributes))
  end

  test "valid with nickname and password" do
    assert build_user.valid?
  end

  test "requires nickname" do
    user = build_user(username: "")

    assert_not user.valid?
    assert_includes user.errors[:username], "не может быть пустым"
  end

  test "nickname must be 3 to 50 characters" do
    assert_not build_user(username: "ab").valid?
    assert build_user(username: "abc").valid?
    assert build_user(username: "a" * 50).valid?
    assert_not build_user(username: "a" * 51).valid?
  end

  test "nickname allows letters of any language, digits and _ . -" do
    assert build_user(username: "Игрок_1").valid?
    assert build_user(username: "dice.chess-42").valid?
    assert_not build_user(username: "with space").valid?
    assert_not build_user(username: "<script>").valid?
  end

  test "strips whitespace around nickname" do
    assert_equal "dave", build_user(username: "  dave  ").username
  end

  test "nickname must be unique regardless of case" do
    user = build_user(username: "ALICE")

    assert_not user.valid?
    assert_includes user.errors[:username], "уже занят"
  end

  test "rating cannot be below the minimum" do
    assert_not build_user(rating: User::MIN_RATING - 1).valid?
    assert build_user(rating: User::MIN_RATING).valid?
  end
end

class UserPasswordTest < ActiveSupport::TestCase
  test "stores password only as bcrypt hash" do
    user = User.create!(username: "dave", password: "secret123")

    assert_not_equal "secret123", user.password_digest
    assert user.password_digest.start_with?("$2")
    assert_equal user, user.authenticate("secret123")
    assert_not user.authenticate("wrong-password")
  end

  test "authenticates users whose hash was made by plain BCrypt" do
    assert_equal users(:alice), User.authenticate_by(username: "alice", password: "secret123")
    assert_nil User.authenticate_by(username: "alice", password: "wrong")
    assert_nil User.authenticate_by(username: "nobody", password: "secret123")
  end

  test "requires password of at least 6 characters" do
    assert_not User.new(username: "dave", password: "").valid?
    assert_not User.new(username: "dave", password: nil).valid?

    short = User.new(username: "dave", password: "12345")
    assert_not short.valid?
    assert_includes short.errors[:password], "слишком короткий (минимум 6)"
  end
end

class UserStatisticsTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @carol = users(:carol)

    start_game(white: @alice, black: @bob, rated: false).finish!(result: "white_win", reason: "checkmate")
    start_game(white: @carol, black: @alice, rated: false).finish!(result: "white_win", reason: "resignation")
    start_game(white: @bob, black: @alice, rated: false).finish!(result: "draw", reason: "stalemate")
    start_game(white: @alice, black: @carol, rated: false)
  end

  test "games include games played as white and as black" do
    assert_equal 4, @alice.games.count
    assert_equal 2, @alice.games_as_white.count
    assert_equal 2, @alice.games_as_black.count
  end

  test "counts wins, losses and draws of finished games only" do
    assert_equal 3, @alice.finished_games_count
    assert_equal 1, @alice.wins_count
    assert_equal 1, @alice.losses_count
    assert_equal 1, @alice.draws_count
  end

  test "statistics of another player are counted separately" do
    assert_equal 0, @bob.wins_count
    assert_equal 1, @bob.losses_count
    assert_equal 1, @bob.draws_count
    assert_equal 1, @carol.wins_count
    assert_equal 0, @carol.losses_count
  end

  test "win rate is a percentage of finished games" do
    assert_equal 33, @alice.win_rate
    assert_equal 0, @bob.win_rate
    assert_equal 100, @carol.win_rate
  end

  test "win rate is zero without finished games" do
    newcomer = User.create!(username: "newcomer", password: "secret123")

    assert_equal 0, newcomer.win_rate
  end

  test "a user with games cannot be destroyed" do
    assert_no_difference "User.count" do
      assert_not @alice.destroy
    end
  end
end

class UserRatingTest < ActiveSupport::TestCase
  test "new players start with the default rating" do
    assert_equal 1500, User.create!(username: "newcomer", password: "secret123").rating
  end

  test "apply_rating_change! adds the delta and returns it" do
    alice = users(:alice)

    assert_equal 16, alice.apply_rating_change!(16)
    assert_equal 1516, alice.reload.rating
    assert_equal(-30, alice.apply_rating_change!(-30))
    assert_equal 1486, alice.reload.rating
  end

  test "rating never drops below the minimum and the real change is returned" do
    alice = users(:alice)
    alice.update!(rating: 110)

    assert_equal(-10, alice.apply_rating_change!(-50))
    assert_equal User::MIN_RATING, alice.reload.rating
  end
end
