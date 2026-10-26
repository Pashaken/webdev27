class GamesController < ApplicationController
  before_action :require_login
  before_action :set_game, except: %i[index create]

  def index
    games = current_user.games.includes(:time_control, game_players: :user).order(created_at: :desc)
    @running = games.where(finished_at: nil)
    @finished = games.finished.limit(5)
    @open = Game.waiting.where.not(id: current_user.games.select(:id))
                .includes(:time_control, game_players: :user).order(created_at: :desc).limit(20)
  end

  def create
    initial, increment = params[:control].to_s.split("+").map(&:to_i)
    game = Game.open_for(
      creator: current_user, color: params[:color].presence || "random",
      initial_seconds: initial, increment_seconds: increment, rated: params[:rated] == "1"
    )
    redirect_to game
  rescue ArgumentError, ActiveRecord::RecordInvalid
    redirect_to root_path, alert: "Не удалось создать партию."
  end

  def show
    @game.expire_clock!
    @position = @game.position
    @moves = @game.moves.includes(:game_dice_state, :game_player).to_a
    @roll = @game.current_roll
    @mine = @game.my_turn?(current_user)
    @playable = @mine && @roll ? @game.playable_dice(@position) : []
    @legal = @mine ? @game.legal_moves(@position) : {}
    @check = @mine && @position.in_check?(@game.turn)
    @selected = params[:from] if @legal.key?(params[:from])
    @refresh = !@game.finished? && !@mine
  end

  def destroy
    @game.cancel!(current_user)
    redirect_to root_path, notice: "Партия отменена."
  rescue Game::Error => error
    redirect_to game_path(@game), alert: error.message
  end

  def join
    act { @game.join!(current_user) }
  end

  def roll
    act { @game.roll_dice!(current_user) }
  end

  def choose
    act { @game.choose_die!(current_user, params[:die].to_i) }
  end

  def reroll
    act { @game.reroll!(current_user) }
  end

  def move
    act { @game.play_move!(user: current_user, from: params[:from].to_s, to: params[:to].to_s) }
  end

  def resign
    act { @game.resign!(current_user) }
  end

  def offer_draw
    act { @game.offer_draw!(current_user) }
  end

  def accept_draw
    act { @game.accept_draw!(current_user) }
  end

  private

  def set_game
    @game = Game.includes(:time_control, game_players: :user).find(params[:id])
  end

  def act
    begin
      @game.expire_clock!
      yield
    rescue Game::Error, ActiveRecord::RecordInvalid => error
      flash[:alert] = error.message
    end

    redirect_to game_path(@game)
  end
end
