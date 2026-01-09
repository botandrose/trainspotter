module Trainspotter
  module Ingest
    class SessionBuilder
      def initialize(configuration: Trainspotter.configuration)
        @configuration = configuration
      end

      def process_request(request, log_file)
        return unless request.completed? && request.ip

        session = find_or_create_session(request.ip, request.started_at, log_file)

        if (email = detect_login(request))
          session.update!(email: email)
        end

        if detect_logout(request)
          session.update!(ended_at: request.started_at, end_reason: "logout")
        end

        RequestRecord.where(log_request_id: request.id).update_all(session_id: session.id)
        session.increment!(:request_count)
        session.update!(ended_at: request.started_at) if session.ongoing?
      end

      def expire_stale_sessions(log_file)
        cutoff = Time.current - @configuration.session_timeout
        SessionRecord.expire_before(cutoff, log_file: log_file)
      end

      private

      def find_or_create_session(ip, timestamp, log_file)
        timeout_cutoff = timestamp - @configuration.session_timeout
        SessionRecord.find_active(ip: ip, after: timeout_cutoff, log_file: log_file) ||
          SessionRecord.create!(ip: ip, started_at: timestamp, log_file: log_file)
      end

      def detect_login(request)
        @configuration.login_detectors.each_value do |detector|
          email = detector.call(request)
          return email if email
        end
        nil
      end

      def detect_logout(request)
        @configuration.logout_detectors.any? { |_, detector| detector.call(request) }
      end
    end
  end
end
