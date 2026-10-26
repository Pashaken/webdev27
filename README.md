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

## База данных и модели

Схема базы (ER-диаграмма, таблицы, правила): [docs/database.md](docs/database.md).
Модели лежат в `app/models/`: `User`, `Game`, `GamePlayer`, `Move`, `DiceState`, `GameDiceState`, `TimeControl`,
`DrawOffer`, а также `Position` (позиция, которая восстанавливается из ходов) и `EloRating` (расчёт рейтинга).
Миграции применяются командой `ruby bin/rails db:migrate`, тесты моделей запускаются командой
`ruby bin/rails test test/models`.

## UI-кит

Стили лежат в `public/ui/`: `tokens.css` (цвета, отступы, шрифты, светлая и тёмная тема), `base.css`,
`components.css` (кнопки, формы, карточки, таблицы, меню), `icons.css`, `game.css` (доска, фигуры, кубики, часы,
список ходов, диалоги партии) и `theme.js` (кнопка смены темы в шапке).
Все компоненты с примерами собраны на отдельной странице `public/ui-kit.html`: она открывается по адресу
`/ui-kit.html` и просто из папки проекта. Страница собирается из шаблона `app/views/ui/index.html.erb` командой
`ruby bin/rails ui:build` (после правок шаблона её нужно пересобрать). В development та же
страница доступна на лету по адресу `/ui`.
