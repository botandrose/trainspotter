require "rails_helper"

RSpec.describe Trainspotter::Ingest::Processor do
  # Disable transactional fixtures since we use a separate database
  self.use_transactional_tests = false

  let(:temp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(temp_dir, "test_trainspotter.sqlite3") }
  let(:log_path) { File.join(temp_dir, "test.log") }

  before do
    allow(Trainspotter).to receive(:database_path).and_return(db_path)
    Trainspotter::Record.reset_connection!
    Trainspotter::Record.ensure_connected
  end

  after do
    Trainspotter::Record.reset_connection!
    FileUtils.remove_entry(temp_dir) rescue nil
  end

  def write_request(file, id:, method: "GET", path: "/", status: 200, controller: "TestController", action: "index")
    file.puts "Started #{method} \"#{path}\" for 127.0.0.1 at 2024-01-15 10:00:00 +0000"
    file.puts "Processing by #{controller}##{action} as HTML"
    file.puts "Completed #{status} OK in 50ms"
    file.puts ""
  end

  describe ".call" do
    it "processes log files and creates request records" do
      File.open(log_path, "w") do |f|
        write_request(f, id: "req1", path: "/posts")
      end

      described_class.call([log_path])

      expect(Trainspotter::RequestRecord.count).to eq(1)
      expect(Trainspotter::RequestRecord.first.path).to eq("/posts")
    end

    it "tracks file position for incremental processing" do
      File.open(log_path, "w") do |f|
        write_request(f, id: "req1", path: "/first")
      end

      described_class.call([log_path])
      expect(Trainspotter::RequestRecord.count).to eq(1)

      File.open(log_path, "a") do |f|
        write_request(f, id: "req2", path: "/second")
      end

      described_class.call([log_path])
      expect(Trainspotter::RequestRecord.count).to eq(2)
    end

    it "respects chunk_size parameter" do
      File.open(log_path, "w") do |f|
        # Write 10 lines
        10.times { |i| f.puts "Line #{i}" }
      end

      # Process only 3 lines at a time
      described_class.call([log_path], chunk_size: 3)

      position = Trainspotter::FilePositionRecord.get_position("test.log")
      # Should have read only 3 lines worth
      expect(position).to be < File.size(log_path)
    end

    it "skips non-existent files" do
      expect {
        described_class.call(["/nonexistent/path.log"])
      }.not_to raise_error
    end

    it "handles log rotation by resetting position" do
      File.open(log_path, "w") do |f|
        write_request(f, id: "req1", path: "/original")
      end

      described_class.call([log_path])
      original_position = Trainspotter::FilePositionRecord.get_position("test.log")

      # Simulate log rotation - new smaller file
      File.open(log_path, "w") do |f|
        f.puts "New"
      end

      described_class.call([log_path])
      new_position = Trainspotter::FilePositionRecord.get_position("test.log")

      expect(new_position).to be < original_position
    end

    it "correctly captures namespaced controller names like Trainspotter::RequestsController" do
      File.open(log_path, "w") do |f|
        write_request(f, id: "req1", path: "/trainspotter/requests", controller: "Trainspotter::RequestsController")
      end

      described_class.call([log_path])

      record = Trainspotter::RequestRecord.first
      expect(record.controller).to eq("Trainspotter::RequestsController")
      expect(Trainspotter.internal_request?(record)).to be true
    end
  end
end
