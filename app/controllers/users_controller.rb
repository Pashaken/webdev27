class UsersController < ApplicationController
  before_action :redirect_if_logged_in

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      log_in(@user)
      redirect_to root_path, notice: "Регистрация прошла успешно. Добро пожаловать!"
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:username, :taken)
    render :new, status: :unprocessable_entity
  end

  private

  def user_params
    params.expect(user: [ :username, :password ])
  end
end
