require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  def log_in_as_alice
    post login_path, params: { username: "alice", password: "secret123" }
  end

  test "anonymous user is redirected from home to login" do
    get root_path
    assert_redirected_to login_path
  end

  test "registration and login pages render forms" do
    get register_path
    assert_response :success
    assert_select "form[action=?]", register_path
    assert_select "input[name=?]", "user[username]"
    assert_select "input[type=password][name=?]", "user[password]"

    get login_path
    assert_response :success
    assert_select "form[action=?]", login_path
    assert_select "input[name=?]", "username"
    assert_select "input[type=password][name=?]", "password"
  end

  test "registration creates user, hashes password and logs in" do
    assert_difference "User.count", 1 do
      post register_path, params: { user: { username: "bob", password: "secret123" } }
    end
    assert_redirected_to root_path

    user = User.find_by!(username: "bob")
    assert user.password_digest.start_with?("$2")
    assert_not_includes user.password_digest, "secret123"

    follow_redirect!
    assert_response :success
    assert_select "h1", "Привет, bob!"
  end

  test "registration with invalid data shows errors and creates nothing" do
    assert_no_difference "User.count" do
      post register_path, params: { user: { username: "bob", password: "123" } }
    end
    assert_response :unprocessable_entity
    assert_select "li", /Пароль слишком короткий/
  end

  test "registration rejects taken nickname in any case" do
    assert_no_difference "User.count" do
      post register_path, params: { user: { username: "Alice", password: "secret123" } }
    end
    assert_response :unprocessable_entity
    assert_select "li", /Никнейм уже занят/
  end

  test "login with correct password" do
    log_in_as_alice
    assert_redirected_to root_path

    follow_redirect!
    assert_select "h1", "Привет, alice!"
  end

  test "login with wrong password or unknown nickname fails with the same message" do
    post login_path, params: { username: "alice", password: "wrong-password" }
    assert_response :unprocessable_entity
    assert_select "p strong", "Неверный никнейм или пароль."

    post login_path, params: { username: "nobody", password: "secret123" }
    assert_response :unprocessable_entity
    assert_select "p strong", "Неверный никнейм или пароль."

    get root_path
    assert_redirected_to login_path
  end

  test "login without parameters fails gracefully" do
    post login_path
    assert_response :unprocessable_entity
  end

  test "logout ends the session" do
    log_in_as_alice
    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "logged in user is redirected away from login and registration pages" do
    log_in_as_alice

    get login_path
    assert_redirected_to root_path

    get register_path
    assert_redirected_to root_path
  end

  test "session of a deleted user is not accepted" do
    log_in_as_alice
    users(:alice).destroy

    get root_path
    assert_redirected_to login_path
  end
end
