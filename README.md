# DiceChess

Регистрация и вход по нику и паролю на Ruby on Rails. Пароли хешируются через bcrypt.

Страницы: `/register`, `/login`, `/logout`. Главная `/` открывается только после входа.

## Запуск

Нужны Ruby и PostgreSQL. По умолчанию подключение к `localhost`, пользователь `postgres` без пароля,
менять через `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` (см. `config/database.yml`).

    bundle install
    ruby bin/rails db:create db:migrate
    ruby bin/rails server

Тесты: `ruby bin/rails test`

## UI-кит

Стили лежат в `public/ui/`: `tokens.css` (цвета, отступы, шрифты, светлая и тёмная тема), `base.css`,
`components.css` (кнопки, формы, карточки, таблицы, меню), `icons.css`, `game.css` (доска, фигуры, кубики, часы,
список ходов, диалоги партии) и `theme.js` (кнопка смены темы в шапке).
Все компоненты с примерами открываются на странице `/ui` в development.
