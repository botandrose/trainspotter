require "rails_helper"

RSpec.describe Trainspotter::BackgroundWorker do
  let(:lock_path) { Rails.root.join("tmp", "trainspotter.lock") }
  let(:default_options) { { interval: 1, lock_path: lock_path } }

  before do
    described_class.instance = nil
    FileUtils.rm_f(lock_path)
  end

  after do
    described_class.stop
    FileUtils.rm_f(lock_path)
  end

  describe ".start" do
    it "creates a lock file when started" do
      described_class.start(**default_options) { }

      expect(File.exist?(lock_path)).to be true
      expect(described_class.instance).to be_running
    end

    it "does not start a second worker if one is running" do
      described_class.start(**default_options) { }
      first_instance = described_class.instance

      described_class.start(**default_options) { }

      expect(described_class.instance).to eq(first_instance)
    end
  end

  describe ".stop" do
    it "stops the worker and releases the lock" do
      described_class.start(**default_options) { }
      expect(described_class.instance).to be_running

      described_class.stop

      expect(described_class.instance).to be_nil
    end
  end

  describe "#acquire_lock" do
    it "acquires lock when no other process holds it" do
      worker = described_class.new(**default_options) { }
      result = worker.send(:acquire_lock)

      expect(result).to be_truthy
      expect(File.exist?(lock_path)).to be true

      worker.send(:release_lock)
    end

    it "fails to acquire lock when another process holds it" do
      worker1 = described_class.new(**default_options) { }
      worker1.send(:acquire_lock)

      worker2 = described_class.new(**default_options) { }
      result = worker2.send(:acquire_lock)

      expect(result).to be_falsey

      worker1.send(:release_lock)
    end
  end

  describe ".start" do
    it "raises ArgumentError when no block is given" do
      expect { described_class.start(**default_options) }.to raise_error(ArgumentError, "a block is required")
    end
  end
end
