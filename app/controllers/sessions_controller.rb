class SessionsController < ApplicationController
  before_action :redirect_if_logged_in, only: %i[new create]

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to login_path, alert: "Слишком много попыток входа. Подождите несколько минут." }

  def new
  end

  def create
    user = User.authenticate_by(username: params[:username].to_s, password: params[:password].to_s)

    if user
      log_in(user)
      redirect_to root_path, notice: "Вы вошли в систему."
    else
      flash.now[:alert] = "Неверный никнейм или пароль."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to login_path, notice: "Вы вышли из системы."
  end
end
