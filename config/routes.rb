Rails.application.routes.draw do
  root "games#index"

  get "register", to: "users#new"
  post "register", to: "users#create"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :games, only: %i[create show destroy] do
    member do
      %i[join roll choose reroll move resign offer_draw accept_draw].each { |action| post action }
    end
  end

  get "ui", to: "ui#index" if Rails.env.local?
end
