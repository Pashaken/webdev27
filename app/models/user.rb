class User < ApplicationRecord
  has_secure_password

  normalizes :username, with: ->(username) { username.strip }

  validates :username,
            presence: true,
            length: { in: 3..50 },
            format: { with: /\A[\p{L}\p{N}_.\-]+\z/,
                      message: "может содержать только буквы, цифры и символы _ . -",
                      allow_blank: true },
            uniqueness: { case_sensitive: false }

  validates :password, length: { minimum: 6 }, allow_nil: true
end
