module GamesHelper
  END_REASON_LABELS = {
    "checkmate" => "Мат",
    "resignation" => "Соперник сдался",
    "timeout" => "Время вышло",
    "stalemate" => "Пат",
    "agreement" => "Ничья по согласию",
    "king_captured" => "Король взят"
  }.freeze

  OUTCOME_BADGES = {
    "win" => [ "Победа", "badge-success" ],
    "loss" => [ "Поражение", "badge-error" ],
    "draw" => [ "Ничья", "badge-warning" ]
  }.freeze

  RESIGNED_LABEL = "Вы сдались".freeze
  COLOR_LABELS = { "white" => "белые", "black" => "чёрные" }.freeze

  def lobby_player(game, color)
    seat = game.game_player_of(color)
    [ seat.user.username, seat.rating_before || seat.user.rating, player_path(seat.user) ] if seat
  end

  def win_rate_text(rate)
    rate ? "#{rate}%" : "—"
  end

  def outcome_badge(outcome)
    OUTCOME_BADGES.fetch(outcome)
  end

  def clock_text(seconds)
    seconds = [ seconds, 0 ].max
    format("%02d:%02d", seconds / 60, seconds % 60)
  end

  def result_reason(game, user)
    return RESIGNED_LABEL if game.end_reason == "resignation" && game.outcome_for(user) == "loss"

    END_REASON_LABELS.fetch(game.end_reason)
  end

  def result_summary(game)
    case game.result
    when "draw" then "Ничья"
    else "Победили #{COLOR_LABELS.fetch(game.result.delete_suffix('_win'))}"
    end
  end

  def rating_change(game, user)
    return "не рейтинговая" unless game.rated?

    delta = game.game_player_for(user)&.rating_delta.to_i
    delta.positive? ? "+#{delta}" : delta.to_s
  end

  def captured_by(moves, color)
    moves.select { |move| move.captured && move.game_player.color == color }
         .map { |move| "#{color == 'white' ? 'b' : 'w'}#{move.captured}" }
  end

  def board_marks(moves, legal, selected, position)
    marks = Hash.new { |hash, square| hash[square] = [] }

    moves.last&.then do |move|
      marks[move.from_square] << :last_move
      marks[move.to_square] << :last_move
    end

    marks[position.king_square(position.turn)] << :check if position.in_check?(position.turn)

    legal.each_key { |square| marks[square] << :clickable }

    if selected
      marks[selected] << :selected
      legal[selected].each do |square|
        marks[square] << (position.captured_piece(from: selected, to: square) ? :capture : :target)
      end
    end

    marks
  end

  def board_actions(game, legal, selected)
    actions = legal.keys.index_with { |square| { url: game_path(game, from: square), label: "Выбрать #{square}" } }
    return actions unless selected

    actions[selected] = { url: game_path(game), label: "Снять выбор" }
    legal[selected].each do |square|
      actions[square] = {
        url: move_game_path(game), method: :post, params: { from: selected, to: square }, label: "Сходить на #{square}"
      }
    end
    actions
  end
end
