require "sqlite3"

module Trainspotter
  class LogRepository
    SCHEMA = <<~SQL
      CREATE TABLE IF NOT EXISTS requests (
        request_id TEXT PRIMARY KEY,
        log_file TEXT NOT NULL,
        method TEXT,
        path TEXT,
        status INTEGER,
        duration_ms REAL,
        ip TEXT,
        controller TEXT,
        action TEXT,
        started_at TEXT,
        entries_json TEXT,
        completed INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_requests_log_file_started_at
        ON requests(log_file, started_at DESC);

      CREATE TABLE IF NOT EXISTS file_positions (
        log_file TEXT PRIMARY KEY,
        position INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    SQL

    def initialize
      @db = SQLite3::Database.new(Trainspotter.database_path)
      @db.results_as_hash = true
      ensure_schema
    end

    def recent_requests(log_file:, limit: nil)
      limit ||= Trainspotter.recent_request_limit
      sync_from_file(log_file)

      rows = @db.execute(<<~SQL, [ log_file, limit ])
        SELECT * FROM requests
        WHERE log_file = ? AND completed = 1
        ORDER BY started_at DESC
        LIMIT ?
      SQL

      rows.map { |row| row_to_request_group(row) }
    end

    def poll_for_changes(log_file:, since_request_id: nil)
      sync_from_file(log_file)

      sql = <<~SQL
        SELECT * FROM requests
        WHERE log_file = ? AND completed = 1
        #{since_request_id ? "AND created_at > (SELECT created_at FROM requests WHERE request_id = ?)" : ""}
        ORDER BY started_at ASC
      SQL

      args = since_request_id ? [ log_file, since_request_id ] : [ log_file ]
      rows = @db.execute(sql, args)

      rows.map { |row| row_to_request_group(row) }
    end

    def sync_from_file(log_file)
      log_path = File.join(Trainspotter.log_directory, log_file)
      return unless File.exist?(log_path)

      position = get_file_position(log_file)
      current_size = File.size(log_path)

      # Handle log rotation
      if current_size < position
        position = 0
      end

      return if current_size == position

      new_lines = read_lines_from_position(log_path, position)
      return if new_lines.empty?

      parser = LogParser.new
      new_lines.each { |line| parser.parse_line(line) }

      parser.groups.each do |group|
        upsert_request(log_file, group)
      end

      update_file_position(log_file, current_size)
    end

    def unique_ips(log_file:)
      rows = @db.execute(<<~SQL, [ log_file ])
        SELECT DISTINCT ip FROM requests
        WHERE log_file = ? AND ip IS NOT NULL
        ORDER BY ip
      SQL

      rows.map { |row| row["ip"] }
    end

    def close
      @db.close
    end

    private

    def ensure_schema
      @db.execute_batch(SCHEMA)
    end

    def get_file_position(log_file)
      row = @db.get_first_row("SELECT position FROM file_positions WHERE log_file = ?", [ log_file ])
      row ? row["position"] : 0
    end

    def update_file_position(log_file, position)
      @db.execute(<<~SQL, [ log_file, position, position ])
        INSERT INTO file_positions (log_file, position, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(log_file) DO UPDATE SET
          position = ?,
          updated_at = CURRENT_TIMESTAMP
      SQL
    end

    def read_lines_from_position(log_path, position)
      lines = []
      File.open(log_path, "r") do |file|
        file.seek(position)
        lines = file.readlines
      end
      lines
    end

    def upsert_request(log_file, group)
      entries_json = group.entries.map do |entry|
        {
          raw: entry.raw,
          type: entry.type,
          timestamp: entry.timestamp&.iso8601,
          metadata: entry.metadata
        }
      end.to_json

      sql = <<~SQL
        INSERT INTO requests (
          request_id, log_file, method, path, status, duration_ms,
          ip, controller, action, started_at, entries_json, completed
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(request_id) DO UPDATE SET
          method = ?,
          path = ?,
          status = ?,
          duration_ms = ?,
          ip = ?,
          controller = ?,
          action = ?,
          started_at = ?,
          entries_json = ?,
          completed = ?
      SQL

      @db.execute(sql, [
        group.id,
        log_file,
        group.method,
        group.path,
        group.status,
        group.duration_ms,
        group.ip,
        group.controller,
        group.action,
        group.started_at&.iso8601,
        entries_json,
        group.completed? ? 1 : 0,
        group.method,
        group.path,
        group.status,
        group.duration_ms,
        group.ip,
        group.controller,
        group.action,
        group.started_at&.iso8601,
        entries_json,
        group.completed? ? 1 : 0
      ])
    end

    def row_to_request_group(row)
      group = RequestGroup.new(id: row["request_id"])

      entries = JSON.parse(row["entries_json"] || "[]")
      entries.each do |entry_data|
        entry = LogEntry.new(
          raw: entry_data["raw"],
          type: entry_data["type"]&.to_sym || :other,
          timestamp: entry_data["timestamp"] ? Time.parse(entry_data["timestamp"]) : nil,
          metadata: (entry_data["metadata"] || {}).transform_keys(&:to_sym)
        )
        group << entry
      end

      group.completed = row["completed"] == 1
      group
    end
  end
end
