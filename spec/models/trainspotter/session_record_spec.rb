require "rails_helper"

RSpec.describe Trainspotter::SessionRecord do
  # Disable transactional fixtures since we use a separate database
  self.use_transactional_tests = false

  let(:temp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(temp_dir, "test_trainspotter.sqlite3") }

  before do
    allow(Trainspotter).to receive(:database_path).and_return(db_path)
    Trainspotter::Record.reset_connection!
    Trainspotter::Record.ensure_connected
  end

  after do
    Trainspotter::Record.reset_connection!
    FileUtils.remove_entry(temp_dir) rescue nil
  end

  describe ".create" do
    it "creates a session with required attributes" do
      session = described_class.create!(
        ip: "192.168.1.1",
        log_file: "production.log"
      )

      expect(session.ip).to eq("192.168.1.1")
      expect(session.log_file).to eq("production.log")
      expect(session.id).to be_present
    end

    it "defaults to ongoing end_reason" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.end_reason).to eq("ongoing")
    end

    it "defaults to zero request_count" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.request_count).to eq(0)
    end

    it "defaults to nil for optional attributes" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.email).to be_nil
      expect(session.started_at).to be_nil
      expect(session.ended_at).to be_nil
    end
  end

  describe ".recent" do
    let(:started_at) { Time.new(2024, 1, 15, 10, 0, 0) }

    it "returns sessions ordered by ended_at descending" do
      described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: started_at, ended_at: started_at + 300, email: "first@example.com")
      described_class.create!(ip: "192.168.1.2", log_file: "test.log", started_at: started_at + 60, ended_at: started_at + 600, email: "second@example.com")

      sessions = described_class.recent(log_file: "test.log")

      expect(sessions.length).to eq(2)
      expect(sessions.first.email).to eq("second@example.com")
    end

    it "orders sessions spanning multiple days correctly by ended_at" do
      # Create sessions across multiple days with varying end times
      jan_10_morning = Time.new(2024, 1, 10, 10, 50, 5)
      jan_10_earlier = Time.new(2024, 1, 10, 10, 27, 11)
      jan_9_evening = Time.new(2024, 1, 9, 21, 1, 50)
      jan_9_afternoon = Time.new(2024, 1, 9, 18, 34, 31)

      # Create in random order to ensure sorting works
      described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: jan_9_afternoon - 300, ended_at: jan_9_afternoon, email: "fourth@example.com")
      described_class.create!(ip: "192.168.1.2", log_file: "test.log", started_at: jan_10_morning - 300, ended_at: jan_10_morning, email: "first@example.com")
      described_class.create!(ip: "192.168.1.3", log_file: "test.log", started_at: jan_9_evening - 300, ended_at: jan_9_evening, email: "third@example.com")
      described_class.create!(ip: "192.168.1.4", log_file: "test.log", started_at: jan_10_earlier - 300, ended_at: jan_10_earlier, email: "second@example.com")

      sessions = described_class.recent(log_file: "test.log")

      expect(sessions.map(&:email)).to eq([
        "first@example.com",   # ended Jan 10 10:50:05 (newest)
        "second@example.com",  # ended Jan 10 10:27:11
        "third@example.com",   # ended Jan 9 21:01:50
        "fourth@example.com"   # ended Jan 9 18:34:31 (oldest)
      ])
    end

    it "excludes anonymous sessions by default" do
      described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: started_at, email: "user@example.com")
      described_class.create!(ip: "192.168.1.2", log_file: "test.log", started_at: started_at + 60)

      sessions = described_class.recent(log_file: "test.log")
      expect(sessions.length).to eq(1)
    end

    it "includes anonymous sessions when requested" do
      described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: started_at, email: "user@example.com")
      described_class.create!(ip: "192.168.1.2", log_file: "test.log", started_at: started_at + 60)

      sessions = described_class.recent(log_file: "test.log", include_anonymous: true)
      expect(sessions.length).to eq(2)
    end
  end

  describe ".find_active" do
    let(:started_at) { Time.new(2024, 1, 15, 10, 0, 0) }

    it "finds an ongoing session for the IP" do
      session = described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: started_at)
      cutoff = started_at - 3600

      found = described_class.find_active(ip: "192.168.1.1", after: cutoff, log_file: "test.log")

      expect(found.id).to eq(session.id)
    end

    it "returns nil when no active session exists" do
      found = described_class.find_active(ip: "192.168.1.1", after: started_at, log_file: "test.log")
      expect(found).to be_nil
    end

    it "does not return ended sessions" do
      described_class.create!(
        ip: "192.168.1.1",
        log_file: "test.log",
        started_at: started_at,
        end_reason: "logout"
      )

      found = described_class.find_active(ip: "192.168.1.1", after: started_at - 3600, log_file: "test.log")
      expect(found).to be_nil
    end
  end

  describe ".expire_before" do
    let(:started_at) { Time.new(2024, 1, 15, 10, 0, 0) }

    it "marks old ongoing sessions as timed out" do
      session = described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: started_at, ended_at: started_at + 60)

      cutoff = started_at + 120
      described_class.expire_before(cutoff, log_file: "test.log")

      session.reload
      expect(session.end_reason).to eq("timeout")
    end

    it "does not expire sessions after the cutoff" do
      session = described_class.create!(ip: "192.168.1.1", log_file: "test.log", started_at: started_at, ended_at: started_at + 300)

      cutoff = started_at + 120
      described_class.expire_before(cutoff, log_file: "test.log")

      session.reload
      expect(session.end_reason).to eq("ongoing")
    end
  end

  describe "#anonymous?" do
    it "returns true when email is nil" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.anonymous?).to be true
    end

    it "returns false when email is set" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        email: "alice@example.com"
      )
      expect(session.anonymous?).to be false
    end
  end

  describe "#ongoing?" do
    it "returns true when end_reason is 'ongoing'" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.ongoing?).to be true
    end

    it "returns false when end_reason is 'logout'" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        end_reason: "logout"
      )
      expect(session.ongoing?).to be false
    end

    it "returns false when end_reason is 'timeout'" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        end_reason: "timeout"
      )
      expect(session.ongoing?).to be false
    end
  end

  describe "#time_range_display" do
    it "returns 'Unknown' when started_at is nil" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.time_range_display).to eq("Unknown")
    end

    it "displays start time to 'now' when ended_at is nil" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.utc(2024, 1, 15, 10, 30)
      )
      expect(session.time_range_display).to match(/Jan 15 \d{2}:30 - now/)
    end

    it "displays start time to end time when both are present" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.utc(2024, 1, 15, 10, 30),
        ended_at: Time.utc(2024, 1, 15, 11, 45)
      )
      # Verify it shows start and end times with correct format
      display = session.time_range_display
      expect(display).to match(/Jan 15 \d{2}:30 - \d{2}:45/)
    end
  end

  describe "#duration_seconds" do
    it "returns nil when started_at is nil" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.duration_seconds).to be_nil
    end

    it "calculates duration to ended_at when present" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.new(2024, 1, 15, 10, 0, 0),
        ended_at: Time.new(2024, 1, 15, 10, 5, 30)
      )
      expect(session.duration_seconds).to eq(330)
    end

    it "calculates duration to current time when ended_at is nil" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.current - 120
      )
      expect(session.duration_seconds).to be_within(1).of(120)
    end
  end

  describe "#duration_display" do
    it "returns 'Unknown' when started_at is nil" do
      session = described_class.create!(ip: "127.0.0.1", log_file: "test.log")
      expect(session.duration_display).to eq("Unknown")
    end

    it "displays seconds for short durations" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.new(2024, 1, 15, 10, 0, 0),
        ended_at: Time.new(2024, 1, 15, 10, 0, 45)
      )
      expect(session.duration_display).to eq("45s")
    end

    it "displays minutes for medium durations" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.new(2024, 1, 15, 10, 0),
        ended_at: Time.new(2024, 1, 15, 10, 15)
      )
      expect(session.duration_display).to eq("15m")
    end

    it "displays hours and minutes for long durations" do
      session = described_class.create!(
        ip: "127.0.0.1",
        log_file: "test.log",
        started_at: Time.new(2024, 1, 15, 10, 0),
        ended_at: Time.new(2024, 1, 15, 12, 30)
      )
      expect(session.duration_display).to eq("2h 30m")
    end
  end
end
