# Схема базы данных

PostgreSQL. Источник правды: миграции в `db/migrate/` и файл `db/schema.rb`.

## ER-диаграмма

```mermaid
erDiagram
    users ||--o{ games : "играет белыми (white_player_id)"
    users ||--o{ games : "играет чёрными (black_player_id)"
    users ||--o{ moves : "делает ход (player_id)"
    games ||--o{ moves : "состоит из ходов (game_id)"

    users {
        int id PK
        string username UK "ник, 3-50 символов"
        string password_digest "bcrypt-хеш пароля"
        int rating "рейтинг Эло, по умолчанию 1500, минимум 100"
        datetime created_at
    }

    games {
        bigint id PK
        int white_player_id FK "может быть пустым, пока нет соперника"
        int black_player_id FK "может быть пустым, пока нет соперника"
        string status "waiting, active, finished"
        string result "white_win, black_win, draw"
        string end_reason "checkmate, resignation, timeout, stalemate, agreement"
        string turn "white или black"
        string fen "текущая позиция"
        boolean rated "влияет ли партия на рейтинг"
        int initial_seconds "время на партию"
        int increment_seconds "добавка за ход"
        int white_seconds_left "остаток времени белых"
        int black_seconds_left "остаток времени чёрных"
        int dice_a "первый кубик текущего хода"
        int dice_b "второй кубик текущего хода"
        int chosen_die "выбранный кубик"
        string draw_offered_by "кто предложил ничью"
        int white_rating_delta "изменение рейтинга белых"
        int black_rating_delta "изменение рейтинга чёрных"
        datetime started_at
        datetime finished_at
        datetime created_at
        datetime updated_at
    }

    moves {
        bigint id PK
        bigint game_id FK
        int player_id FK
        int ply "номер хода, 1, 2, 3 ..."
        string color "white или black"
        string piece "p, n, b, r, q, k"
        string from_square "например e2"
        string to_square "например e4"
        string san "запись хода"
        string captured "съеденная фигура"
        int die_a "первый кубик"
        int die_b "второй кубик"
        int die_used "кубик, которым сделан ход"
        string fen_after "позиция после хода"
        int spent_seconds "затраченное время"
        datetime created_at
    }
```

## Таблицы

### users
Игроки. Таблица создана ещё первой версией проекта, миграция `CreateUsers` подхватывает уже существующую.
Миграция `AddRatingToUsers` добавляет рейтинг. Ограничения: уникальный ник, `rating >= 100`.

### games
Партия двух игроков. Создатель занимает свободное место (белые или чёрные), второе место пустое, пока соперник
не присоединится (`status = waiting`). Состояние кубиков текущего хода хранится прямо в партии
(`dice_a`, `dice_b`, `chosen_die`) и очищается после хода.

Ограничения на уровне БД: допустимые значения `status`, `turn`, `result`, кубики от 1 до 6,
игрок не может играть сам с собой, остаток времени не отрицательный. Индексы: по `status`,
по `white_player_id` и `black_player_id`.

### moves
Каждый ход партии. Вместе с ходом сохраняются оба выпавших кубика и тот, которым ходили
(`die_used`), позиция после хода и затраченное время. Уникальный индекс `(game_id, ply)` не даёт
записать два хода с одним номером. Проверки: `ply > 0`, `die_used` равен одному из двух кубиков.

## Связи в моделях

| Модель | Связи |
|---|---|
| `User` | `has_many :games_as_white`, `:games_as_black`, `:moves` (удаление игрока с партиями запрещено) |
| `Game` | `belongs_to :white_player`, `:black_player` (оба необязательны), `has_many :moves` (по порядку `ply`, удаляются вместе с партией) |
| `Move` | `belongs_to :game`, `:player` |

## Бизнес-правила

- **Кубики и фигуры.** Игрок бросает два кубика и выбирает значение одного из них. Значение определяет фигуру,
  которой можно ходить: 1 пешка, 2 конь, 3 слон, 4 ладья, 5 ферзь, 6 король (`Game::DICE_PIECES`).
  Ход фигурой, не соответствующей выбранному кубику, не записывается.
- **Очередь хода.** Бросать кубики, выбирать кубик и ходить может только игрок, чья очередь.
- **Часы.** При ходе вычитается затраченное время и добавляется добавка за ход. Если время вышло, партия
  заканчивается поражением по времени, а ход не записывается.
- **Ничья.** Один игрок предлагает, другой принимает; собственное предложение принять нельзя, ход сбрасывает предложение.
- **Рейтинг.** В рейтинговой партии по окончании рейтинги меняются по формуле Эло (`EloRating`, K = 32),
  изменение сохраняется в `white_rating_delta` и `black_rating_delta`. Рейтинг не опускается ниже 100.
- **Статистика игрока.** `User#wins_count`, `#losses_count`, `#draws_count`, `#win_rate` считаются по завершённым партиям.

Правила шахмат (допустимые клетки хода, шах, мат) в моделях пока не проверяются: позицию и запись хода передаёт
игровой движок, а модель следит за очередью, кубиками, временем и результатом.
