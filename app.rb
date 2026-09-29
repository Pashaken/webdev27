require 'sinatra'
require_relative 'app/services/auth_service'

configure do
  enable :sessions                            
  set :session_secret, 'qweqweqweqweqeqweqweqweqweqweqweqweqweqweqweqqeqeqeqew' 
  set :public_folder, 'public'                
end


get '/' do
  redirect '/login.html'
end

post '/register' do
  result = AuthService.register(params[:username], params[:password])
  
  if result[:success]
    redirect '/login.html'
  else
    "<h1>Ошибка регистрации</h1><p>#{result[:message]}</p><a href='/register.html'>Назад</a>"
  end
end

post '/login' do
  result = AuthService.login(params[:username], params[:password], session)
  
  if result[:success]
    "<h1>Привет, #{params[:username]}!</h1><p>Вы успешно вошли в DiceChess.</p><p>Ваш ID сессии: #{session[:user_id]}</p>"
  else
    "<h1>Ошибка входа</h1><p>#{result[:message]}</p><a href='/login.html'>Назад</a>"
  end
end
