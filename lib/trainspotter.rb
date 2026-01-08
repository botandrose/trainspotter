require "trainspotter/version"
require "trainspotter/engine"

module Trainspotter
  DEFAULT_FILTERED_PATHS = [
    %r{^/assets/},
    %r{^/packs/},
    %r{^/vite/},
    %r{^/rails/active_storage/},
    %r{^/cable$},
    %r{\.map$},
    %r{\.hot-update\.}
  ].freeze

  class << self
    def log_directory
      @log_directory || default_log_directory
    end

    def log_directory=(path)
      @log_directory = path
    end

    def available_log_files
      Dir.glob(File.join(log_directory, "*.log")).map { |f| File.basename(f) }.sort
    end

    def default_log_file
      "#{Rails.env}.log"
    end

    def filtered_paths
      @filtered_paths ||= DEFAULT_FILTERED_PATHS.dup
    end

    def filtered_paths=(patterns)
      @filtered_paths = patterns
    end

    def filter_request?(path)
      filtered_paths.any? { |pattern| pattern.match?(path) }
    end

    def internal_request?(group)
      group.controller&.start_with?("Trainspotter::")
    end

    def recent_request_limit
      @recent_request_limit || 100
    end

    def recent_request_limit=(limit)
      @recent_request_limit = limit
    end

    def database_path
      @database_path || Rails.root.join("tmp", "trainspotter.sqlite3").to_s
    end

    def database_path=(path)
      @database_path = path
    end

    def reset_filters!
      @filtered_paths = DEFAULT_FILTERED_PATHS.dup
    end

    private

    def default_log_directory
      Rails.root.join("log").to_s
    end
  end
end
