module Trainspotter
  module Ingest
    class Line
      TYPES = %i[request_start processing params sql render request_end other].freeze

      attr_reader :raw, :type, :timestamp, :metadata

      def initialize(raw:, type: :other, timestamp: nil, metadata: {})
        @raw = raw
        @type = type
        @timestamp = timestamp
        @metadata = metadata
      end

      def sql?
        type == :sql
      end

      def render?
        type == :render
      end

      def request_start?
        type == :request_start
      end

      def request_end?
        type == :request_end
      end

      def processing?
        type == :processing
      end

      def params?
        type == :params
      end

      def duration_ms
        metadata[:duration_ms]
      end
    end
  end
end
