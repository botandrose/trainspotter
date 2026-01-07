require "rails_helper"

RSpec.describe Trainspotter do
  let(:log_dir) { Rails.root.join("tmp", "trainspotter_test_logs") }

  before do
    FileUtils.mkdir_p(log_dir)
  end

  after do
    FileUtils.rm_rf(log_dir)
    described_class.log_directory = nil
  end

  describe ".log_directory" do
    it "defaults to Rails log directory" do
      expect(described_class.log_directory).to eq(Rails.root.join("log").to_s)
    end

    it "can be configured" do
      described_class.log_directory = "/custom/path"
      expect(described_class.log_directory).to eq("/custom/path")
    end
  end

  describe ".available_log_files" do
    before do
      described_class.log_directory = log_dir.to_s
    end

    it "returns empty array when no log files exist" do
      expect(described_class.available_log_files).to eq([])
    end

    it "returns only .log files" do
      FileUtils.touch(log_dir.join("development.log"))
      FileUtils.touch(log_dir.join("test.log"))
      FileUtils.touch(log_dir.join("other.txt"))
      FileUtils.touch(log_dir.join("production.log"))

      files = described_class.available_log_files

      expect(files).to contain_exactly("development.log", "production.log", "test.log")
    end

    it "returns files sorted alphabetically" do
      FileUtils.touch(log_dir.join("zebra.log"))
      FileUtils.touch(log_dir.join("alpha.log"))
      FileUtils.touch(log_dir.join("beta.log"))

      expect(described_class.available_log_files).to eq(["alpha.log", "beta.log", "zebra.log"])
    end
  end

  describe ".default_log_file" do
    it "returns the current environment log file" do
      expect(described_class.default_log_file).to eq("test.log")
    end
  end
end
