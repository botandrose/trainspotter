require "rails_helper"

RSpec.describe Trainspotter::RequestGroup do
  def build_entry(type:, metadata: {})
    Trainspotter::LogEntry.new(raw: "", type: type, metadata: metadata)
  end

  describe "#initialize" do
    it "generates a unique id" do
      group1 = described_class.new
      group2 = described_class.new

      expect(group1.id).not_to eq(group2.id)
    end

    it "starts with empty entries" do
      group = described_class.new
      expect(group.entries).to be_empty
    end

    it "starts as not completed" do
      group = described_class.new
      expect(group.completed?).to be false
    end
  end

  describe "#<<" do
    it "adds entries to the group" do
      group = described_class.new
      entry = build_entry(type: :sql)

      group << entry

      expect(group.entries).to include(entry)
    end
  end

  describe "request metadata accessors" do
    let(:group) do
      g = described_class.new
      g << build_entry(type: :request_start, metadata: { method: "GET", path: "/posts" })
      g << build_entry(type: :processing, metadata: { controller: "PostsController", action: "index" })
      g << build_entry(type: :request_end, metadata: { status: 200, duration_ms: 50.0 })
      g.completed = true
      g
    end

    it "#method returns the HTTP method" do
      expect(group.method).to eq("GET")
    end

    it "#path returns the request path" do
      expect(group.path).to eq("/posts")
    end

    it "#ip returns nil when not present in metadata" do
      expect(group.ip).to be_nil
    end

    it "#ip returns the client IP when present" do
      group_with_ip = described_class.new
      group_with_ip << build_entry(type: :request_start, metadata: { method: "GET", path: "/", ip: "192.168.1.100" })
      expect(group_with_ip.ip).to eq("192.168.1.100")
    end

    it "#controller returns the controller name" do
      expect(group.controller).to eq("PostsController")
    end

    it "#action returns the action name" do
      expect(group.action).to eq("index")
    end

    it "#status returns the response status" do
      expect(group.status).to eq(200)
    end

    it "#duration_ms returns the total duration" do
      expect(group.duration_ms).to eq(50.0)
    end
  end

  describe "sql and render helpers" do
    let(:group) do
      g = described_class.new
      g << build_entry(type: :sql, metadata: { duration_ms: 1.5 })
      g << build_entry(type: :sql, metadata: { duration_ms: 2.5 })
      g << build_entry(type: :render, metadata: { duration_ms: 10.0 })
      g
    end

    it "#sql_entries returns only sql entries" do
      expect(group.sql_entries.size).to eq(2)
      expect(group.sql_entries).to all(be_sql)
    end

    it "#render_entries returns only render entries" do
      expect(group.render_entries.size).to eq(1)
      expect(group.render_entries.first).to be_render
    end

    it "#sql_count returns the number of sql queries" do
      expect(group.sql_count).to eq(2)
    end

    it "#sql_duration_ms sums sql durations" do
      expect(group.sql_duration_ms).to eq(4.0)
    end

    it "#render_count returns the number of renders" do
      expect(group.render_count).to eq(1)
    end

    it "#render_duration_ms sums render durations" do
      expect(group.render_duration_ms).to eq(10.0)
    end
  end

  describe "#status_class" do
    it "returns 'success' for 2xx status" do
      group = described_class.new
      group << build_entry(type: :request_end, metadata: { status: 200 })
      expect(group.status_class).to eq("success")
    end

    it "returns 'redirect' for 3xx status" do
      group = described_class.new
      group << build_entry(type: :request_end, metadata: { status: 302 })
      expect(group.status_class).to eq("redirect")
    end

    it "returns 'client-error' for 4xx status" do
      group = described_class.new
      group << build_entry(type: :request_end, metadata: { status: 404 })
      expect(group.status_class).to eq("client-error")
    end

    it "returns 'server-error' for 5xx status" do
      group = described_class.new
      group << build_entry(type: :request_end, metadata: { status: 500 })
      expect(group.status_class).to eq("server-error")
    end

    it "returns 'unknown' for nil status" do
      group = described_class.new
      expect(group.status_class).to eq("unknown")
    end
  end

  describe "#started_at" do
    it "returns the timestamp from the request_start entry" do
      time = Time.new(2024, 1, 6, 10, 0, 0)
      group = described_class.new
      group << Trainspotter::LogEntry.new(
        raw: "",
        type: :request_start,
        timestamp: time,
        metadata: { method: "GET", path: "/" }
      )

      expect(group.started_at).to eq(time)
    end
  end
end
