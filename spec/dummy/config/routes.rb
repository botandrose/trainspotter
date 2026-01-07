Rails.application.routes.draw do
  mount Trainspotter::Engine => "/trainspotter"

  get "up" => "rails/health#show", as: :rails_health_check
end
