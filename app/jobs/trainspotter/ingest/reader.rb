module Trainspotter
  module Ingest
    class Reader
      attr_reader :path, :parser

      def initialize(filename = nil)
        @filename = filename || Trainspotter.default_log_file
        @path = File.join(Trainspotter.log_directory, @filename)
        @parser = Parser.new
        @file_position = 0
      end

      def read_recent(limit: 100)
        return [] unless File.exist?(path)

        lines = tail_lines(limit * 20)
        groups = parser.parse_lines(lines)
        groups.last(limit)
      end

      def read_new_lines
        return [] unless File.exist?(path)

        current_size = File.size(path)

        if current_size < @file_position
          @file_position = 0
        end

        return [] if current_size == @file_position

        new_lines = []
        File.open(path, "r") do |file|
          file.seek(@file_position)
          new_lines = file.readlines
          @file_position = file.pos
        end

        new_lines
      end

      def poll_for_changes
        new_lines = read_new_lines
        return [] if new_lines.empty?

        new_groups = []
        new_lines.each do |line|
          parser.parse_line(line)
          if parser.groups.any? && parser.groups.last.completed?
            new_groups << parser.groups.last
          end
        end

        new_groups
      end

      private

      def tail_lines(count)
        return [] unless File.exist?(path)

        lines = []
        File.open(path, "r") do |file|
          file.seek(0, IO::SEEK_END)
          buffer = ""
          chunk_size = 8192

          while lines.size < count && file.pos > 0
            read_size = [ chunk_size, file.pos ].min
            file.seek(-read_size, IO::SEEK_CUR)
            chunk = file.read(read_size)
            file.seek(-read_size, IO::SEEK_CUR)
            buffer = chunk + buffer
            lines = buffer.lines
          end

          @file_position = file.size
        end

        lines.last(count)
      end
    end
  end
end
