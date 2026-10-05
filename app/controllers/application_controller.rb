class ApplicationController < ActionController::Base
  helper_method :current_user

  private

  def current_user
    return unless session[:user_id]
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def log_in(user)
    reset_session
    session[:user_id] = user.id
  end

  def log_out
    reset_session
  end

  def require_login
    redirect_to login_path, alert: "Войдите в аккаунт, чтобы продолжить." unless logged_in?
  end

  def redirect_if_logged_in
    redirect_to root_path if logged_in?
  end
end
