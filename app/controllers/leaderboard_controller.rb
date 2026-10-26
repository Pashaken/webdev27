class LeaderboardController < ApplicationController
  LIMIT = 100

  before_action :require_login

  def index
    @users = User.order(rating: :desc, username: :asc).limit(LIMIT).to_a
    ids = @users.map(&:id)

    @games = grouped(GamePlayer.in_finished_games, ids)
    @wins = grouped(GamePlayer.won, ids)
    @losses = grouped(GamePlayer.lost, ids)
    @draws = grouped(GamePlayer.drawn, ids)
  end

  private

  def grouped(scope, ids)
    scope.where(user_id: ids).group(:user_id).count
  end
end
