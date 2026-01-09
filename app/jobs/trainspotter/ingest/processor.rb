module Trainspotter
  module Ingest
    class Processor < Struct.new(:log_path, :session_builder, :chunk_size, keyword_init: true)
      DEFAULT_CHUNK_SIZE = 10_000

      def self.call(log_paths, chunk_size: DEFAULT_CHUNK_SIZE)
        session_builder = Ingest::SessionBuilder.new

        log_paths.each do |log_path|
          next unless File.exist?(log_path)
          new(log_path:, session_builder:, chunk_size:).call
        end
      end

      def call
        if position = unread_position
          process_chunk(position)
          expire_stale_sessions
        end
      end

      private

      def log_filename
        File.basename(log_path)
      end

      def unread_position
        position = FilePositionRecord.get_position(log_filename)
        file_size = File.size(log_path)

        # Handle log rotation
        position = 0 if file_size < position
        return if file_size == position

        position
      end

      def process_chunk(position)
        new_position, lines = read_chunk(position)
        return if lines.empty?

        parse_and_persist(lines)
        FilePositionRecord.update_position(log_filename, new_position)
      end

      def parse_and_persist(lines)
        parser = Parser.new
        lines.each { |line| parser.parse_line(line) }

        parser.groups.each do |request|
          RequestRecord.upsert_from_request(log_filename, request)
          session_builder.process_request(request, log_filename) if request.completed?
        end
      end

      def expire_stale_sessions
        session_builder.expire_stale_sessions(log_filename)
      end

      def read_chunk(position)
        File.open(log_path, "r") do |file|
          file.seek(position)
          lines = file.each_line.take(chunk_size || DEFAULT_CHUNK_SIZE).to_a
          [file.pos, lines]
        end
      end
    end
  end
end
