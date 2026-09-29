require_relative '../models/user'

class AuthService
  # Метод регистрации нового юзера
  def self.register(username, password)
    return { success: false, message: "Заполните все поля!" } if username.to_s.strip.empty? || password.to_s.strip.empty?

    user_data = User.create(username, password)
    if user_data
      { success: true, message: "Регистрация успешна!" }
    else
      { success: false, message: "Пользователь с таким именем уже существует." }
    end
  end

  # Метод входа юзера в систему
  def self.login(username, password, session_hash)
    return { success: false, message: "Заполните все поля!" } if username.to_s.strip.empty? || password.to_s.strip.empty?

    user = User.find_by_username(username)

    if user && user.valid_password?(password)
      session_hash[:user_id] = user.id
      { success: true, message: "Вы успешно вошли в DiceChess!", user: user }
    else
      { success: false, message: "Неверное имя пользователя или пароль." }
    end
  end

  # Метод выхода из системы
  def self.logout(session_hash)
    session_hash.delete(:user_id)
    { success: true, message: "Вы вышли из системы." }
  end
end
