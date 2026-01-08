ENV["RAILS_ENV"] ||= "test"
ENV["RAILS_ROOT"] = File.expand_path("../../spec/dummy", __dir__)

require_relative "../../spec/dummy/config/environment"

require "cucumber/rails"
require "capybara/cuprite"
require "rspec/mocks"

World(RSpec::Mocks::ExampleMethods)

Before do
  RSpec::Mocks.setup
  # Clean up SQLite database before each scenario
  db_path = Rails.root.join("tmp", "trainspotter.sqlite3")
  FileUtils.rm_f(db_path)
end

After do
  begin
    RSpec::Mocks.verify
  ensure
    RSpec::Mocks.teardown
  end
end

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1280, 800 ], headless: true, process_timeout: 30)
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite

ActionController::Base.allow_rescue = true

DatabaseCleaner.strategy = :transaction
Cucumber::Rails::Database.javascript_strategy = :truncation
