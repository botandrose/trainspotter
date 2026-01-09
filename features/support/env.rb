ENV["RAILS_ENV"] ||= "test"
ENV["RAILS_ROOT"] = File.expand_path("../../spec/dummy", __dir__)

require_relative "../../spec/dummy/config/environment"

require "cucumber/rails"
