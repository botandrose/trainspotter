require "rails_helper"

RSpec.describe Trainspotter::LogParser do
  describe "#parse_line" do
    let(:parser) { described_class.new }

    context "with request start line" do
      let(:line) { 'Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000' }

      it "creates a request_start entry" do
        entry = parser.parse_line(line)

        expect(entry.type).to eq(:request_start)
        expect(entry.metadata[:method]).to eq("GET")
        expect(entry.metadata[:path]).to eq("/posts")
        expect(entry.metadata[:ip]).to eq("127.0.0.1")
      end

      it "parses the timestamp" do
        entry = parser.parse_line(line)

        expect(entry.timestamp).to be_a(Time)
        expect(entry.timestamp.year).to eq(2024)
      end

      it "starts a new request group" do
        parser.parse_line(line)

        expect(parser.groups).to be_empty # not finalized yet
      end
    end

    context "with processing line" do
      let(:line) { "Processing by PostsController#index as HTML" }

      it "creates a processing entry" do
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        entry = parser.parse_line(line)

        expect(entry.type).to eq(:processing)
        expect(entry.metadata[:controller]).to eq("PostsController")
        expect(entry.metadata[:action]).to eq("index")
        expect(entry.metadata[:format]).to eq("HTML")
      end
    end

    context "with SQL query line" do
      let(:line) { '  Post Load (0.5ms)  SELECT "posts".* FROM "posts"' }

      it "creates a sql entry" do
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        entry = parser.parse_line(line)

        expect(entry.type).to eq(:sql)
        expect(entry.metadata[:name]).to eq("Post Load")
        expect(entry.metadata[:duration_ms]).to eq(0.5)
        expect(entry.metadata[:query]).to eq('SELECT "posts".* FROM "posts"')
      end
    end

    context "with render line" do
      let(:line) { "  Rendered posts/index.html.erb within layouts/application (Duration: 5.0ms | GC: 0.0ms)" }

      it "creates a render entry" do
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        entry = parser.parse_line(line)

        expect(entry.type).to eq(:render)
        expect(entry.metadata[:template]).to eq("posts/index.html.erb")
        expect(entry.metadata[:layout]).to eq("layouts/application")
        expect(entry.metadata[:duration_ms]).to eq(5.0)
      end

      it "handles renders without layout" do
        line = "  Rendered posts/_post.html.erb (Duration: 1.2ms | GC: 0.0ms)"
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        entry = parser.parse_line(line)

        expect(entry.type).to eq(:render)
        expect(entry.metadata[:template]).to eq("posts/_post.html.erb")
        expect(entry.metadata[:layout]).to be_nil
      end
    end

    context "with request end line" do
      let(:line) { "Completed 200 OK in 50ms (Views: 40.0ms | ActiveRecord: 5.0ms | Allocations: 1234)" }

      it "creates a request_end entry" do
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        entry = parser.parse_line(line)

        expect(entry.type).to eq(:request_end)
        expect(entry.metadata[:status]).to eq(200)
        expect(entry.metadata[:duration_ms]).to eq(50.0)
      end

      it "finalizes the current group" do
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        parser.parse_line(line)

        expect(parser.groups.size).to eq(1)
        expect(parser.groups.first.completed?).to be true
      end
    end

    context "with unrecognized line" do
      it "creates an other entry" do
        parser.parse_line('Started GET "/" for 127.0.0.1 at 2024-01-06 10:00:00 +0000')
        entry = parser.parse_line("  Parameters: {}")

        expect(entry.type).to eq(:other)
        expect(entry.raw).to eq("  Parameters: {}")
      end
    end

    context "with empty line" do
      it "returns nil" do
        expect(parser.parse_line("")).to be_nil
        expect(parser.parse_line("   ")).to be_nil
      end
    end
  end

  describe "#parse_lines" do
    let(:parser) { described_class.new }

    it "parses multiple lines into request groups" do
      lines = [
        'Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
        "Processing by PostsController#index as HTML",
        '  Post Load (0.5ms)  SELECT "posts".* FROM "posts"',
        "  Rendered posts/index.html.erb within layouts/application (Duration: 5.0ms | GC: 0.0ms)",
        "Completed 200 OK in 50ms (Views: 40.0ms | ActiveRecord: 5.0ms)"
      ]

      groups = parser.parse_lines(lines)

      expect(groups.size).to eq(1)

      group = groups.first
      expect(group.method).to eq("GET")
      expect(group.path).to eq("/posts")
      expect(group.controller).to eq("PostsController")
      expect(group.action).to eq("index")
      expect(group.status).to eq(200)
      expect(group.sql_count).to eq(1)
      expect(group.render_count).to eq(1)
    end

    it "handles multiple requests" do
      lines = [
        'Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
        "Completed 200 OK in 50ms (Views: 40.0ms)",
        'Started POST "/posts" for 127.0.0.1 at 2024-01-06 10:00:01 +0000',
        "Completed 302 Found in 30ms"
      ]

      groups = parser.parse_lines(lines)

      expect(groups.size).to eq(2)
      expect(groups[0].method).to eq("GET")
      expect(groups[0].status).to eq(200)
      expect(groups[1].method).to eq("POST")
      expect(groups[1].status).to eq(302)
    end

    it "handles incomplete requests at end of log" do
      lines = [
        'Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
        "Processing by PostsController#index as HTML"
      ]

      groups = parser.parse_lines(lines)

      expect(groups.size).to eq(1)
      expect(groups.first.completed?).to be false
    end
  end

  describe "#parse_file" do
    let(:parser) { described_class.new }
    let(:log_file) { Rails.root.join("tmp", "test.log") }

    before do
      FileUtils.mkdir_p(Rails.root.join("tmp"))
    end

    after do
      FileUtils.rm_f(log_file)
    end

    it "parses a log file" do
      File.write(log_file, <<~LOG)
        Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
        Processing by PostsController#index as HTML
        Completed 200 OK in 50ms
      LOG

      groups = parser.parse_file(log_file)

      expect(groups.size).to eq(1)
      expect(groups.first.status).to eq(200)
    end

    it "respects limit parameter" do
      File.write(log_file, <<~LOG)
        Started GET "/a" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
        Completed 200 OK in 50ms
        Started GET "/b" for 127.0.0.1 at 2024-01-06 10:00:01 +0000
        Completed 200 OK in 50ms
      LOG

      groups = parser.parse_file(log_file, limit: 2)

      expect(groups.size).to eq(1) # only first request fits in 2 lines
    end
  end

  describe "tagged logger support" do
    let(:parser) { described_class.new }

    context "with request ID tags" do
      it "parses lines with request ID prefix" do
        lines = [
          '[abc123] Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
          "[abc123] Processing by PostsController#index as HTML",
          "[abc123] Completed 200 OK in 50ms"
        ]

        groups = parser.parse_lines(lines)

        expect(groups.size).to eq(1)
        expect(groups.first.method).to eq("GET")
        expect(groups.first.path).to eq("/posts")
        expect(groups.first.status).to eq(200)
        expect(groups.first.id).to eq("abc123")
      end

      it "correctly groups interleaved requests by request ID" do
        lines = [
          '[req-1] Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
          '[req-2] Started POST "/users" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
          '[req-1] Processing by PostsController#index as HTML',
          '[req-2] Processing by UsersController#create as JSON',
          '  [req-1] Post Load (0.5ms)  SELECT "posts".* FROM "posts"',
          '  [req-2] User Create (1.2ms)  INSERT INTO "users"',
          "[req-2] Completed 201 Created in 30ms",
          "[req-1] Completed 200 OK in 50ms"
        ]

        groups = parser.parse_lines(lines)

        expect(groups.size).to eq(2)

        req2_group = groups.find { |g| g.id == "req-2" }
        req1_group = groups.find { |g| g.id == "req-1" }

        expect(req1_group.method).to eq("GET")
        expect(req1_group.path).to eq("/posts")
        expect(req1_group.controller).to eq("PostsController")
        expect(req1_group.status).to eq(200)
        expect(req1_group.sql_count).to eq(1)

        expect(req2_group.method).to eq("POST")
        expect(req2_group.path).to eq("/users")
        expect(req2_group.controller).to eq("UsersController")
        expect(req2_group.status).to eq(201)
        expect(req2_group.sql_count).to eq(1)
      end

      it "handles UUID-style request IDs" do
        lines = [
          '[5de6cb4c-4a8e-4d87-bafd-3ce2281e26f4] Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
          "[5de6cb4c-4a8e-4d87-bafd-3ce2281e26f4] Completed 200 OK in 50ms"
        ]

        groups = parser.parse_lines(lines)

        expect(groups.size).to eq(1)
        expect(groups.first.id).to eq("5de6cb4c-4a8e-4d87-bafd-3ce2281e26f4")
      end

      it "marks groups as completed when request_end is seen" do
        lines = [
          '[req-1] Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
          "[req-1] Completed 200 OK in 50ms"
        ]

        groups = parser.parse_lines(lines)

        expect(groups.first.completed?).to be true
      end

      it "handles incomplete tagged requests at end of log" do
        lines = [
          '[req-1] Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000',
          "[req-1] Processing by PostsController#index as HTML"
        ]

        groups = parser.parse_lines(lines)

        expect(groups.size).to eq(1)
        expect(groups.first.completed?).to be false
      end
    end
  end
end
