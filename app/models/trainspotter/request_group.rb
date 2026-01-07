module Trainspotter
  class RequestGroup
    attr_reader :id, :entries
    attr_accessor :completed

    def initialize(id: nil)
      @id = id || SecureRandom.hex(8)
      @entries = []
      @completed = false
    end

    def <<(entry)
      @entries << entry
    end

    def completed?
      @completed
    end

    def method
      start_entry&.metadata&.dig(:method) || "?"
    end

    def path
      start_entry&.metadata&.dig(:path) || "?"
    end

    def ip
      start_entry&.metadata&.dig(:ip)
    end

    def controller
      processing_entry&.metadata&.dig(:controller)
    end

    def action
      processing_entry&.metadata&.dig(:action)
    end

    def status
      end_entry&.metadata&.dig(:status)
    end

    def duration_ms
      end_entry&.metadata&.dig(:duration_ms)
    end

    def started_at
      start_entry&.timestamp
    end

    def sql_entries
      @entries.select(&:sql?)
    end

    def render_entries
      @entries.select(&:render?)
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

    private

    def start_entry
      @entries.find(&:request_start?)
    end

    def processing_entry
      @entries.find(&:processing?)
    end

    def end_entry
      @entries.find(&:request_end?)
    end
  end
end
