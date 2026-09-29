require 'bcrypt'
require_relative '../../config/database'

class User
  attr_reader :id, :username, :password_digest

  def initialize(attributes = {})
    @id = attributes['id']
    @username = attributes['username']
    @password_digest = attributes['password_digest']
  end

  # ищем юзера в бд
  def self.find_by_username(username)
    result = Database.connect.exec_params(
      "SELECT * FROM users WHERE username = $1 LIMIT 1", 
      [username]
    )
    return nil if result.ntuples.zero?
    new(result.first)
  end

  #создаем юзера
  def self.create(username, password)
    hashed_password = BCrypt::Password.create(password)
    #хешируем пароль
    result = Database.connect.exec_params(
      "INSERT INTO users (username, password_digest) VALUES ($1, $2) RETURNING id, username",
      [username, hashed_password]
    )
    result.first
  rescue PG::UniqueViolation
    nil # Никнейм уже занят
  end

  def valid_password?(password)
    BCrypt::Password.new(@password_digest) == password
  end
end
