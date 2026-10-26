class ProfilesController < ApplicationController
  before_action :require_login

  def show
    @user = params[:id] ? User.find(params[:id]) : current_user
    @history = @user.game_players.in_finished_games
                    .includes(game: { game_players: :user })
                    .order("games.finished_at DESC").limit(10).to_a
    @move_counts = Move.where(game_id: @history.map(&:game_id)).group(:game_id).count
  end
end
