require "rails_helper"

RSpec.describe Trainspotter::Ingest::Line do
  describe "#initialize" do
    it "creates an entry with raw content and type" do
      entry = described_class.new(raw: "some log line", type: :sql)

      expect(entry.raw).to eq("some log line")
      expect(entry.type).to eq(:sql)
    end

    it "defaults type to :other" do
      entry = described_class.new(raw: "some log line")

      expect(entry.type).to eq(:other)
    end

    it "accepts metadata" do
      entry = described_class.new(
        raw: "query",
        type: :sql,
        metadata: { duration_ms: 5.2, query: "SELECT 1" }
      )

      expect(entry.metadata[:duration_ms]).to eq(5.2)
      expect(entry.metadata[:query]).to eq("SELECT 1")
    end

    it "accepts timestamp" do
      time = Time.now
      entry = described_class.new(raw: "line", timestamp: time)

      expect(entry.timestamp).to eq(time)
    end
  end

  describe "type predicates" do
    it "#sql? returns true for sql type" do
      entry = described_class.new(raw: "", type: :sql)
      expect(entry.sql?).to be true
      expect(entry.render?).to be false
    end

    it "#render? returns true for render type" do
      entry = described_class.new(raw: "", type: :render)
      expect(entry.render?).to be true
      expect(entry.sql?).to be false
    end

    it "#request_start? returns true for request_start type" do
      entry = described_class.new(raw: "", type: :request_start)
      expect(entry.request_start?).to be true
    end

    it "#request_end? returns true for request_end type" do
      entry = described_class.new(raw: "", type: :request_end)
      expect(entry.request_end?).to be true
    end

    it "#processing? returns true for processing type" do
      entry = described_class.new(raw: "", type: :processing)
      expect(entry.processing?).to be true
    end
  end

  describe "#duration_ms" do
    it "returns duration from metadata" do
      entry = described_class.new(raw: "", metadata: { duration_ms: 12.5 })
      expect(entry.duration_ms).to eq(12.5)
    end

    it "returns nil when no duration in metadata" do
      entry = described_class.new(raw: "")
      expect(entry.duration_ms).to be_nil
    end
  end
end
