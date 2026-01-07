require "trainspotter/silent_request"

module Trainspotter
  class Engine < ::Rails::Engine
    isolate_namespace Trainspotter

    initializer "trainspotter.assets.precompile" do |app|
      app.config.assets.precompile += %w[trainspotter/application.css]
    end

    initializer "trainspotter.middleware" do |app|
      app.middleware.insert_before Rails::Rack::Logger, Trainspotter::SilentRequest
    end
  end
end
