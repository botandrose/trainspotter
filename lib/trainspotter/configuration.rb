module Trainspotter
  class Configuration
    class << self
      def setting(name, default: nil, &block)
        attr_writer name

        ivar = :"@#{name}"
        define_method(name) do
          unless instance_variable_defined?(ivar)
            instance_variable_set(ivar, block ? instance_eval(&block) : default)
          end
          instance_variable_get(ivar)
        end
      end
    end

    setting(:log_directory) { Rails.root.join("log").to_s }
    setting(:database_path) { Rails.root.join("tmp", "trainspotter.sqlite3").to_s }
    setting(:session_timeout) { 30.minutes }
    setting(:background_worker_interval) { 2.seconds }
    setting :recent_request_limit, default: 100

    setting(:filtered_paths) do
      [
        %r{^/assets/},
        %r{^/packs/},
        %r{^/vite/},
        %r{^/rails/active_storage/},
        %r{^/cable$},
        %r{\.map$},
        %r{\.hot-update\.}
      ]
    end

    setting(:login_detectors) do
      {
        session_create: ->(request) {
          return nil unless request.method == "POST" && request.path == "/session"
          request.params&.dig("session", "email")
        }
      }
    end

    setting(:logout_detectors) do
      {
        session_destroy: ->(request) {
          request.method == "DELETE" && request.path == "/session"
        }
      }
    end

    def available_log_files
      Dir.glob(File.join(log_directory, "*.log")).map { |f| File.basename(f) }.sort
    end

    def default_log_file
      "#{Rails.env}.log"
    end

    def filter_request?(path)
      filtered_paths.any? { |pattern| pattern.match?(path) }
    end

    def internal_request?(request)
      request.controller&.start_with?("Trainspotter::")
    end
  end
end
