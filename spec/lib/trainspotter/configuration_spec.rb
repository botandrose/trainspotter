require "rails_helper"

RSpec.describe Trainspotter::Configuration do
  subject(:config) { described_class.new }

  let(:log_dir) { Rails.root.join("tmp", "trainspotter_test_logs") }

  before do
    FileUtils.mkdir_p(log_dir)
  end

  after do
    FileUtils.rm_rf(log_dir)
  end

  describe "#log_directory" do
    it "defaults to Rails log directory" do
      expect(config.log_directory).to eq(Rails.root.join("log").to_s)
    end

    it "can be configured" do
      config.log_directory = "/custom/path"
      expect(config.log_directory).to eq("/custom/path")
    end
  end

  describe "#available_log_files" do
    before do
      config.log_directory = log_dir.to_s
    end

    it "returns empty array when no log files exist" do
      expect(config.available_log_files).to eq([])
    end

    it "returns only .log files" do
      FileUtils.touch(log_dir.join("development.log"))
      FileUtils.touch(log_dir.join("test.log"))
      FileUtils.touch(log_dir.join("other.txt"))
      FileUtils.touch(log_dir.join("production.log"))

      files = config.available_log_files

      expect(files).to contain_exactly("development.log", "production.log", "test.log")
    end

    it "returns files sorted alphabetically" do
      FileUtils.touch(log_dir.join("zebra.log"))
      FileUtils.touch(log_dir.join("alpha.log"))
      FileUtils.touch(log_dir.join("beta.log"))

      expect(config.available_log_files).to eq([ "alpha.log", "beta.log", "zebra.log" ])
    end
  end

  describe "#default_log_file" do
    it "returns the current environment log file" do
      expect(config.default_log_file).to eq("test.log")
    end
  end

  describe "#filtered_paths" do
    it "returns default filtered paths" do
      expect(config.filtered_paths).to include(%r{/assets/})
    end

    it "can be customized" do
      config.filtered_paths = [ %r{^/custom/} ]
      expect(config.filtered_paths).to eq([ %r{^/custom/} ])
    end
  end

  describe "#filter_request?" do
    it "filters asset paths" do
      expect(config.filter_request?("/assets/application.js")).to be true
      expect(config.filter_request?("/assets/styles.css")).to be true
    end

    it "filters webpack/vite paths" do
      expect(config.filter_request?("/packs/application.js")).to be true
      expect(config.filter_request?("/vite/client")).to be true
    end

    it "filters active storage paths" do
      expect(config.filter_request?("/rails/active_storage/blobs/123")).to be true
    end

    it "filters action cable path" do
      expect(config.filter_request?("/cable")).to be true
    end

    it "filters source maps" do
      expect(config.filter_request?("/assets/application.js.map")).to be true
    end

    it "filters hot reload updates" do
      expect(config.filter_request?("/assets/main.hot-update.js")).to be true
    end

    it "does not filter regular paths" do
      expect(config.filter_request?("/posts")).to be false
      expect(config.filter_request?("/users/123")).to be false
      expect(config.filter_request?("/api/v1/items")).to be false
    end

    it "respects custom filters" do
      config.filtered_paths = [ %r{^/admin/} ]
      expect(config.filter_request?("/admin/dashboard")).to be true
      expect(config.filter_request?("/assets/app.js")).to be false
    end
  end

  describe "#internal_request?" do
    let(:request) { instance_double(Trainspotter::Request) }

    it "returns true for Trainspotter controllers" do
      allow(request).to receive(:controller).and_return("Trainspotter::RequestsController")
      expect(config.internal_request?(request)).to be true
    end

    it "returns false for other controllers" do
      allow(request).to receive(:controller).and_return("PostsController")
      expect(config.internal_request?(request)).to be false
    end

    it "returns falsey when controller is nil" do
      allow(request).to receive(:controller).and_return(nil)
      expect(config.internal_request?(request)).to be_falsey
    end
  end

  describe "#session_timeout" do
    it "defaults to 30 minutes" do
      expect(config.session_timeout).to eq(30.minutes)
    end

    it "can be configured" do
      config.session_timeout = 1.hour
      expect(config.session_timeout).to eq(1.hour)
    end
  end

  describe "#login_detectors" do
    it "includes default session_create detector" do
      expect(config.login_detectors).to have_key(:session_create)
    end

    it "can add custom detectors" do
      config.login_detectors[:devise] = ->(request) { request.path == "/users/sign_in" }
      expect(config.login_detectors).to have_key(:devise)
    end
  end

  describe "#logout_detectors" do
    it "includes default session_destroy detector" do
      expect(config.logout_detectors).to have_key(:session_destroy)
    end

    it "can add custom detectors" do
      config.logout_detectors[:devise] = ->(request) { request.path == "/users/sign_out" }
      expect(config.logout_detectors).to have_key(:devise)
    end
  end
end
