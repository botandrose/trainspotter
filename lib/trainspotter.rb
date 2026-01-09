require "trainspotter/version"
require "trainspotter/configuration"
require "trainspotter/engine"
require "trainspotter/background_worker"

module Trainspotter
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def method_missing(method, *args, &block)
      if configuration.respond_to?(method)
        configuration.public_send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      configuration.respond_to?(method) || super
    end
  end
end
