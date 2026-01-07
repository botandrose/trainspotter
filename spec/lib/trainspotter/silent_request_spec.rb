require "rails_helper"

RSpec.describe Trainspotter::SilentRequest do
  let(:app) { ->(env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(app) }

  describe "#call" do
    it "passes through non-trainspotter requests" do
      env = { "PATH_INFO" => "/posts" }
      expect(app).to receive(:call).with(env).and_call_original
      middleware.call(env)
    end

    it "silences the logger for trainspotter requests" do
      env = { "PATH_INFO" => "/trainspotter" }
      original_logger = Rails.logger

      middleware.call(env)

      expect(Rails.logger).to eq(original_logger)
    end

    it "silences the logger for trainspotter sub-paths" do
      env = { "PATH_INFO" => "/trainspotter/logs" }
      original_logger = Rails.logger

      middleware.call(env)

      expect(Rails.logger).to eq(original_logger)
    end

    it "restores the logger after the request" do
      env = { "PATH_INFO" => "/trainspotter" }
      original_logger = Rails.logger

      middleware.call(env)

      expect(Rails.logger).to eq(original_logger)
    end

    it "restores the logger even if the app raises an error" do
      error_app = ->(_env) { raise "Test error" }
      error_middleware = described_class.new(error_app)
      env = { "PATH_INFO" => "/trainspotter" }
      original_logger = Rails.logger

      expect { error_middleware.call(env) }.to raise_error("Test error")
      expect(Rails.logger).to eq(original_logger)
    end
  end
end
