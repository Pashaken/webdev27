class ProfilesController < ApplicationController
  PER_PAGE = 20
  MAX_PAGE = 10_000

  before_action :require_login

  def show
    @user = params[:id] ? User.find(params[:id]) : current_user
    @page = params[:page].to_i.clamp(1, MAX_PAGE)

    rows = @user.game_players.in_finished_games
                .includes(game: { game_players: :user })
                .order("games.finished_at DESC, games.id DESC")
                .offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a

    @has_next = rows.size > PER_PAGE
    @history = rows.first(PER_PAGE)
    @move_counts = Move.where(game_id: @history.map(&:game_id)).group(:game_id).count
  end
end
