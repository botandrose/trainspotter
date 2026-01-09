require "rails_helper"

RSpec.describe Trainspotter::Ingest::SessionBuilder do
  # Disable transactional fixtures since we use a separate database
  self.use_transactional_tests = false

  let(:temp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(temp_dir, "test_trainspotter.sqlite3") }
  let(:configuration) { Trainspotter::Configuration.new }
  let(:builder) { described_class.new(configuration: configuration) }

  before do
    allow(Trainspotter).to receive(:database_path).and_return(db_path)
    Trainspotter::Record.reset_connection!
    Trainspotter::Record.ensure_connected
  end

  after do
    Trainspotter::Record.reset_connection!
    FileUtils.remove_entry(temp_dir) rescue nil
  end

  def build_request(method:, path:, ip:, started_at:, completed: true, params: nil)
    request = Trainspotter::Request.new(id: SecureRandom.hex(8))
    request << Trainspotter::Ingest::Line.new(
      raw: "",
      type: :request_start,
      timestamp: started_at,
      metadata: { method: method, path: path, ip: ip }
    )
    if params
      request << Trainspotter::Ingest::Line.new(
        raw: "",
        type: :params,
        metadata: { params: params }
      )
    end
    request << Trainspotter::Ingest::Line.new(
      raw: "",
      type: :request_end,
      metadata: { status: 200, duration_ms: 50.0 }
    )
    request.completed = completed
    request
  end

  describe "#process_request" do
    let(:started_at) { Time.new(2024, 1, 15, 10, 0, 0) }

    before do
      # Pre-create a request in the database so we can test assignment
      Trainspotter::RequestRecord.create!(
        log_request_id: "test-request",
        log_file: "test.log",
        ip: "192.168.1.1",
        completed: true
      )
    end

    it "does nothing for incomplete requests" do
      request = build_request(method: "GET", path: "/", ip: "192.168.1.1", started_at: started_at, completed: false)

      expect {
        builder.process_request(request, "test.log")
      }.not_to change { Trainspotter::SessionRecord.count }
    end

    it "does nothing for requests without IP" do
      request = build_request(method: "GET", path: "/", ip: nil, started_at: started_at)

      expect {
        builder.process_request(request, "test.log")
      }.not_to change { Trainspotter::SessionRecord.count }
    end

    it "creates a new session if none exists" do
      request = build_request(method: "GET", path: "/", ip: "192.168.1.1", started_at: started_at)

      # Create the request record in the database
      Trainspotter::RequestRecord.create!(
        log_request_id: request.id,
        log_file: "test.log",
        ip: "192.168.1.1",
        completed: true
      )

      expect {
        builder.process_request(request, "test.log")
      }.to change { Trainspotter::SessionRecord.count }.by(1)

      session = Trainspotter::SessionRecord.last
      expect(session.ip).to eq("192.168.1.1")
      expect(session.log_file).to eq("test.log")
    end

    it "reuses existing active session" do
      Trainspotter::SessionRecord.create!(
        ip: "192.168.1.1",
        log_file: "test.log",
        started_at: started_at - 60,
        end_reason: "ongoing"
      )

      request = build_request(method: "GET", path: "/", ip: "192.168.1.1", started_at: started_at)
      Trainspotter::RequestRecord.create!(
        log_request_id: request.id,
        log_file: "test.log",
        ip: "192.168.1.1",
        completed: true
      )

      expect {
        builder.process_request(request, "test.log")
      }.not_to change { Trainspotter::SessionRecord.count }
    end

    it "assigns request to session" do
      request = build_request(method: "GET", path: "/", ip: "192.168.1.1", started_at: started_at)
      Trainspotter::RequestRecord.create!(
        log_request_id: request.id,
        log_file: "test.log",
        ip: "192.168.1.1",
        completed: true
      )

      builder.process_request(request, "test.log")

      request_record = Trainspotter::RequestRecord.find_by(log_request_id: request.id)
      expect(request_record.session_id).to be_present
    end

    it "increments session request count" do
      request = build_request(method: "GET", path: "/", ip: "192.168.1.1", started_at: started_at)
      Trainspotter::RequestRecord.create!(
        log_request_id: request.id,
        log_file: "test.log",
        ip: "192.168.1.1",
        completed: true
      )

      builder.process_request(request, "test.log")

      session = Trainspotter::SessionRecord.last
      expect(session.request_count).to eq(1)
    end

    it "updates session ended_at" do
      request = build_request(method: "GET", path: "/", ip: "192.168.1.1", started_at: started_at)
      Trainspotter::RequestRecord.create!(
        log_request_id: request.id,
        log_file: "test.log",
        ip: "192.168.1.1",
        completed: true
      )

      builder.process_request(request, "test.log")

      session = Trainspotter::SessionRecord.last
      expect(session.ended_at).to eq(started_at)
    end

    context "with login request" do
      it "detects login and updates session email" do
        request = build_request(
          method: "POST",
          path: "/session",
          ip: "192.168.1.1",
          started_at: started_at,
          params: { "session" => { "email" => "alice@example.com", "password" => "[FILTERED]" } }
        )
        Trainspotter::RequestRecord.create!(
          log_request_id: request.id,
          log_file: "test.log",
          ip: "192.168.1.1",
          completed: true
        )

        builder.process_request(request, "test.log")

        session = Trainspotter::SessionRecord.last
        expect(session.email).to eq("alice@example.com")
      end

      it "does not update email for non-login requests" do
        request = build_request(
          method: "GET",
          path: "/dashboard",
          ip: "192.168.1.1",
          started_at: started_at
        )
        Trainspotter::RequestRecord.create!(
          log_request_id: request.id,
          log_file: "test.log",
          ip: "192.168.1.1",
          completed: true
        )

        builder.process_request(request, "test.log")

        session = Trainspotter::SessionRecord.last
        expect(session.email).to be_nil
      end
    end

    context "with logout request" do
      it "detects logout and ends session" do
        request = build_request(
          method: "DELETE",
          path: "/session",
          ip: "192.168.1.1",
          started_at: started_at
        )
        Trainspotter::RequestRecord.create!(
          log_request_id: request.id,
          log_file: "test.log",
          ip: "192.168.1.1",
          completed: true
        )

        builder.process_request(request, "test.log")

        session = Trainspotter::SessionRecord.last
        expect(session.end_reason).to eq("logout")
      end

      it "does not end session for non-logout requests" do
        request = build_request(
          method: "GET",
          path: "/dashboard",
          ip: "192.168.1.1",
          started_at: started_at
        )
        Trainspotter::RequestRecord.create!(
          log_request_id: request.id,
          log_file: "test.log",
          ip: "192.168.1.1",
          completed: true
        )

        builder.process_request(request, "test.log")

        session = Trainspotter::SessionRecord.last
        expect(session.end_reason).to eq("ongoing")
      end
    end

    context "with custom detectors" do
      it "uses custom login detector" do
        configuration.login_detectors[:devise] = ->(request) {
          return nil unless request.method == "POST" && request.path == "/users/sign_in"
          request.params&.dig("user", "email")
        }

        request = build_request(
          method: "POST",
          path: "/users/sign_in",
          ip: "192.168.1.1",
          started_at: started_at,
          params: { "user" => { "email" => "bob@example.com", "password" => "[FILTERED]" } }
        )
        Trainspotter::RequestRecord.create!(
          log_request_id: request.id,
          log_file: "test.log",
          ip: "192.168.1.1",
          completed: true
        )

        builder.process_request(request, "test.log")

        session = Trainspotter::SessionRecord.last
        expect(session.email).to eq("bob@example.com")
      end

      it "uses custom logout detector" do
        configuration.logout_detectors[:devise] = ->(request) {
          request.method == "DELETE" && request.path == "/users/sign_out"
        }

        request = build_request(
          method: "DELETE",
          path: "/users/sign_out",
          ip: "192.168.1.1",
          started_at: started_at
        )
        Trainspotter::RequestRecord.create!(
          log_request_id: request.id,
          log_file: "test.log",
          ip: "192.168.1.1",
          completed: true
        )

        builder.process_request(request, "test.log")

        session = Trainspotter::SessionRecord.last
        expect(session.end_reason).to eq("logout")
      end
    end
  end

  describe "#expire_stale_sessions" do
    it "expires sessions older than timeout" do
      started_at = Time.new(2024, 1, 15, 10, 0, 0)
      session = Trainspotter::SessionRecord.create!(
        ip: "192.168.1.1",
        log_file: "test.log",
        started_at: started_at,
        ended_at: started_at + 60
      )

      freeze_time = started_at + configuration.session_timeout + 120
      allow(Time).to receive(:current).and_return(freeze_time)

      builder.expire_stale_sessions("test.log")

      session.reload
      expect(session.end_reason).to eq("timeout")
    end
  end
end
