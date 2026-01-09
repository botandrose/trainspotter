Trainspotter::Engine.routes.draw do
  root to: "requests#index"

  resources :requests, only: [:index] do
    collection do
      get :poll
    end
  end

  resources :sessions, only: [:index] do
    member do
      get :requests
    end
  end
end
