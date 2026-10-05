require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attributes)
    User.new({ username: "bob", password: "secret123" }.merge(attributes))
  end

  test "valid with nickname and password" do
    assert build_user.valid?
  end

  test "stores password only as bcrypt hash" do
    user = build_user
    user.save!

    assert_not_equal "secret123", user.password_digest
    assert user.password_digest.start_with?("$2"), "ожидался bcrypt-хеш"
    assert_equal user, user.authenticate("secret123")
    assert_not user.authenticate("wrong-password")
  end

  test "authenticates users whose hash was made by plain BCrypt (old Sinatra version)" do
    assert_equal users(:alice), User.authenticate_by(username: "alice", password: "secret123")
    assert_nil User.authenticate_by(username: "alice", password: "wrong")
    assert_nil User.authenticate_by(username: "nobody", password: "secret123")
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
    assert_equal "bob", build_user(username: "  bob  ").username
  end

  test "nickname must be unique regardless of case" do
    user = build_user(username: "ALICE")
    assert_not user.valid?
    assert_includes user.errors[:username], "уже занят"
  end

  test "requires password of at least 6 characters" do
    assert_not build_user(password: "").valid?
    assert_not build_user(password: nil).valid?

    short = build_user(password: "12345")
    assert_not short.valid?
    assert_includes short.errors[:password], "слишком короткий (минимум 6)"
  end
end
