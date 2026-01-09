require "rails_helper"

RSpec.describe Trainspotter::Ingest::Reader do
  let(:log_dir) { Rails.root.join("tmp", "test_logs") }
  let(:log_file) { log_dir.join("test.log") }

  before do
    FileUtils.mkdir_p(log_dir)
    allow(Trainspotter).to receive(:log_directory).and_return(log_dir.to_s)
  end

  after do
    FileUtils.rm_rf(log_dir)
  end

  describe "#initialize" do
    it "uses the provided filename" do
      FileUtils.touch(log_file)
      reader = described_class.new("test.log")
      expect(reader.path).to eq(log_file.to_s)
    end

    it "defaults to Rails environment log" do
      reader = described_class.new
      expect(reader.path).to eq(log_dir.join("test.log").to_s)
    end
  end

  describe "#read_recent" do
    it "returns empty array when file does not exist" do
      reader = described_class.new("nonexistent.log")
      expect(reader.read_recent).to eq([])
    end

    it "parses recent requests from the log file" do
      File.write(log_file, <<~LOG)
        Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
        Processing by PostsController#index as HTML
        Completed 200 OK in 50ms
        Started GET "/users" for 127.0.0.1 at 2024-01-06 10:00:01 +0000
        Processing by UsersController#index as HTML
        Completed 200 OK in 30ms
      LOG

      reader = described_class.new("test.log")
      groups = reader.read_recent(limit: 10)

      expect(groups.size).to eq(2)
      expect(groups.first.path).to eq("/posts")
      expect(groups.last.path).to eq("/users")
    end

    it "respects the limit parameter" do
      File.write(log_file, <<~LOG)
        Started GET "/a" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
        Completed 200 OK in 50ms
        Started GET "/b" for 127.0.0.1 at 2024-01-06 10:00:01 +0000
        Completed 200 OK in 30ms
        Started GET "/c" for 127.0.0.1 at 2024-01-06 10:00:02 +0000
        Completed 200 OK in 20ms
      LOG

      reader = described_class.new("test.log")
      groups = reader.read_recent(limit: 2)

      expect(groups.size).to eq(2)
    end
  end

  describe "#read_new_lines" do
    it "returns empty array when file does not exist" do
      reader = described_class.new("nonexistent.log")
      expect(reader.read_new_lines).to eq([])
    end

    it "returns all lines on first read" do
      File.write(log_file, "line 1\nline 2\n")

      reader = described_class.new("test.log")
      lines = reader.read_new_lines

      expect(lines.map(&:strip)).to eq([ "line 1", "line 2" ])
    end

    it "returns only new lines on subsequent reads" do
      File.write(log_file, "line 1\n")

      reader = described_class.new("test.log")
      reader.read_new_lines # first read

      File.open(log_file, "a") { |f| f.write("line 2\nline 3\n") }
      new_lines = reader.read_new_lines

      expect(new_lines.map(&:strip)).to eq([ "line 2", "line 3" ])
    end

    it "handles file truncation (log rotation)" do
      File.write(log_file, "old line 1\nold line 2\n")

      reader = described_class.new("test.log")
      reader.read_new_lines

      # Simulate log rotation - file is truncated
      File.write(log_file, "new line 1\n")
      new_lines = reader.read_new_lines

      expect(new_lines.map(&:strip)).to eq([ "new line 1" ])
    end
  end

  describe "#poll_for_changes" do
    it "returns empty array when no new content" do
      File.write(log_file, "")

      reader = described_class.new("test.log")
      reader.read_new_lines # initial read

      expect(reader.poll_for_changes).to eq([])
    end

    it "returns completed request groups from new lines" do
      File.write(log_file, "")

      reader = described_class.new("test.log")
      reader.read_new_lines # initial empty read

      File.open(log_file, "a") do |f|
        f.write(<<~LOG)
          Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
          Processing by PostsController#index as HTML
          Completed 200 OK in 50ms
        LOG
      end

      groups = reader.poll_for_changes

      expect(groups.size).to eq(1)
      expect(groups.first.path).to eq("/posts")
      expect(groups.first.completed?).to be true
    end

    it "does not return incomplete requests" do
      File.write(log_file, "")

      reader = described_class.new("test.log")
      reader.read_new_lines

      File.open(log_file, "a") do |f|
        f.write(<<~LOG)
          Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
          Processing by PostsController#index as HTML
        LOG
      end

      groups = reader.poll_for_changes

      expect(groups).to be_empty
    end
  end
end
