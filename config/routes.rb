Trainspotter::Engine.routes.draw do
  root to: "logs#index"
  get "poll", to: "logs#poll", as: :poll_logs
end
