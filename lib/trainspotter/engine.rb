module Trainspotter
  class Engine < ::Rails::Engine
    isolate_namespace Trainspotter

    initializer "trainspotter.assets.precompile" do |app|
      app.config.assets.precompile += %w[trainspotter/application.css]
    end

    initializer "trainspotter.silence_requests" do
      config.after_initialize { Engine.silence_engine_requests }
    end

    initializer "trainspotter.background_worker" do
      config.after_initialize do
        Engine.start_background_worker unless Rails.env.test?
      end

      at_exit { Trainspotter::BackgroundWorker.stop }
    end

    def self.silence_engine_requests
      if mount_path = engine_mount_path
        Rails.application.config.middleware.insert_before(
          Rails::Rack::Logger,
          Rails::Rack::SilenceRequest,
          path: %r{^#{Regexp.escape(mount_path)}}
        )
      end
    end

    def self.engine_mount_path
      route = Rails.application.routes.routes.find do |r|
        r.app.respond_to?(:app) && r.app.app == Trainspotter::Engine
      end
      route&.path&.spec&.to_s&.chomp("(.:format)")
    end

    def self.start_background_worker
      Trainspotter::BackgroundWorker.start(
        interval: Trainspotter.background_worker_interval,
        lock_path: Rails.root.join("tmp", "trainspotter.lock"),
        logger: Rails.logger
      ) do
        Trainspotter::IngestJob.new.perform
      end
    end
  end
end
