Rails.application.routes.draw do
  root "home#index"

  get "register", to: "users#new"
  post "register", to: "users#create"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "ui", to: "ui#index" if Rails.env.local?
end
