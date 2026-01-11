module Trainspotter
  class SessionRecord < Record
    self.table_name = "sessions"

    has_many :request_records,
             class_name: "Trainspotter::RequestRecord",
             foreign_key: "session_id"

    scope :for_log_file, ->(log_file) { where(log_file: log_file) }
    scope :identified, -> { where.not(email: nil) }
    scope :ongoing, -> { where(end_reason: "ongoing") }

    scope :recent, ->(log_file:, include_anonymous: false, limit: 50) {
      scope = for_log_file(log_file).order(ended_at: :desc).limit(limit)
      include_anonymous ? scope : scope.identified
    }

    def self.find_active(ip:, after:, log_file:)
      where(ip: ip, log_file: log_file, end_reason: "ongoing")
        .where("started_at > ?", after)
        .order(started_at: :desc)
        .first
    end

    def self.expire_before(cutoff, log_file:)
      ongoing
        .for_log_file(log_file)
        .where("ended_at < ?", cutoff)
        .update_all(end_reason: "timeout")
    end

    attribute :id, :string, default: -> { SecureRandom.hex(8) }

    def anonymous?
      email.nil?
    end

    def ongoing?
      end_reason == "ongoing"
    end

    def time_range_display
      return "Unknown" unless started_at
      start_str = started_at.strftime("%b %d %H:%M")
      end_str = ended_at&.strftime("%H:%M") || "now"
      "#{start_str} - #{end_str}"
    end

    def duration_seconds
      return nil unless started_at
      end_time = ended_at || Time.current
      (end_time - started_at).to_i
    end

    def duration_display
      seconds = duration_seconds
      return "Unknown" unless seconds

      if seconds < 60
        "#{seconds}s"
      elsif seconds < 3600
        minutes = seconds / 60
        "#{minutes}m"
      else
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        "#{hours}h #{minutes}m"
      end
    end
  end
end
