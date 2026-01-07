ENV["RAILS_ENV"] ||= "test"
ENV["RAILS_ROOT"] = File.expand_path("../../spec/dummy", __dir__)

require_relative "../../spec/dummy/config/environment"

require "cucumber/rails"
require "capybara/cuprite"
require "rspec/mocks"

World(RSpec::Mocks::ExampleMethods)

Before do
  RSpec::Mocks.setup
end

After do
  begin
    RSpec::Mocks.verify
  ensure
    RSpec::Mocks.teardown
  end
end

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1280, 800], headless: true)
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite

ActionController::Base.allow_rescue = true

DatabaseCleaner.strategy = :transaction
Cucumber::Rails::Database.javascript_strategy = :truncation
