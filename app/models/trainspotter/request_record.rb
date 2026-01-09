module Trainspotter
  class RequestRecord < Record
    self.table_name = "requests"

    belongs_to :session_record,
               class_name: "Trainspotter::SessionRecord",
               foreign_key: "session_id",
               optional: true

    scope :completed, -> { where(completed: true) }
    scope :for_log_file, ->(log_file) { where(log_file: log_file) }

    scope :recent, ->(log_file:, limit: nil) {
      limit ||= Trainspotter.recent_request_limit
      for_log_file(log_file).completed.order(started_at: :desc).limit(limit)
    }

    scope :since, ->(since_id) {
      return all unless since_id

      reference = find_by(id: since_id)
      return none unless reference

      where("created_at > ?", reference.created_at)
    }

    def self.poll_for_changes(log_file:, since_id: nil)
      for_log_file(log_file)
        .completed
        .since(since_id)
        .order(started_at: :asc)
    end

    def self.unique_ips(log_file:)
      for_log_file(log_file)
        .where.not(ip: nil)
        .distinct
        .pluck(:ip)
        .sort
    end

    def self.upsert_from_request(log_file, request)
      entries_data = request.entries.map do |entry|
        {
          raw: entry.raw,
          type: entry.type,
          timestamp: entry.timestamp&.iso8601,
          metadata: entry.metadata
        }
      end

      upsert(
        {
          log_request_id: request.id,
          log_file: log_file,
          method: request.method,
          path: request.path,
          status: request.status,
          duration_ms: request.duration_ms,
          ip: request.ip,
          controller: request.controller,
          action: request.action,
          started_at: request.started_at,
          entries_json: entries_data,
          completed: request.completed?
        },
        unique_by: :log_request_id
      )
    end

    def self.for_session(session_id, limit: 100)
      where(session_id: session_id)
        .completed
        .order(started_at: :asc)
        .limit(limit)
    end

    serialize :entries_json, coder: JSON

    def entries
      parsed_entries
    end

    def sql_entries
      parsed_entries.select(&:sql?)
    end

    def render_entries
      parsed_entries.select(&:render?)
    end

    private def parsed_entries
      @parsed_entries ||= (entries_json || []).map do |data|
        Ingest::Line.new(
          raw: data["raw"],
          type: data["type"]&.to_sym || :other,
          timestamp: data["timestamp"] ? Time.parse(data["timestamp"]) : nil,
          metadata: (data["metadata"] || {}).transform_keys(&:to_sym)
        )
      end
    end

    def sql_count
      sql_entries.size
    end

    def sql_duration_ms
      sql_entries.sum { |e| e.duration_ms || 0 }
    end

    def render_count
      render_entries.size
    end

    def render_duration_ms
      render_entries.sum { |e| e.duration_ms || 0 }
    end

    def status_class
      case status
      when 200..299 then "success"
      when 300..399 then "redirect"
      when 400..499 then "client-error"
      when 500..599 then "server-error"
      else "unknown"
      end
    end

    def completed?
      completed
    end
  end
end
