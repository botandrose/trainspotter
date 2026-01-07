module Trainspotter
  class SilentRequest
    def initialize(app)
      @app = app
    end

    def call(env)
      if trainspotter_request?(env)
        silence_request(env) { @app.call(env) }
      else
        @app.call(env)
      end
    end

    private

    def trainspotter_request?(env)
      path = env["PATH_INFO"]
      path&.start_with?("/trainspotter")
    end

    def silence_request(env)
      old_logger = Rails.logger
      Rails.logger = Logger.new(nil)
      env["action_dispatch.logger"] = Rails.logger

      yield
    ensure
      Rails.logger = old_logger
    end
  end
end
