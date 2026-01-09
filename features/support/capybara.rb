require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1280, 800 ], headless: true, process_timeout: 30)
end

Capybara.default_driver = :cuprite

ActionController::Base.allow_rescue = true
