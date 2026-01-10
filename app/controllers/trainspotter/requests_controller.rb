module Trainspotter
  class RequestsController < ApplicationController
    include ActionController::Live

    def index
      @current_log_file = params[:log_file] || Trainspotter.default_log_file
      @current_ip = params[:ip].presence
      @available_log_files = Trainspotter.available_log_files

      all_requests = filter_requests(RequestRecord.recent(log_file: @current_log_file))
      @available_ips = RequestRecord.unique_ips(log_file: @current_log_file)
      @requests = filter_by_ip(all_requests).first(50)
      @last_id = @requests.first&.id
    end

    def stream
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      log_file = params[:log_file] || Trainspotter.default_log_file
      ip_filter = params[:ip].presence
      last_id = params[:since_id].presence

      sse = SSE.new(response.stream, event: "message")

      loop do
        new_requests = filter_by_ip(
          filter_requests(RequestRecord.poll_for_changes(log_file: log_file, since_id: last_id)),
          ip_filter
        )

        new_requests.each do |request|
          html = render_request_turbo_stream(request)
          sse.write(html)
          last_id = request.id
        end

        sleep 1
      end
    rescue IOError, ActionController::Live::ClientDisconnected
      # Client disconnected - this is normal
    ensure
      sse.close
    end

    private

    def render_request_turbo_stream(request)
      html = render_to_string(partial: "trainspotter/requests/request", locals: { request: request })
      <<~TURBO
        <turbo-stream action="append" target="request-list">
          <template>#{html}</template>
        </turbo-stream>
        <turbo-stream action="remove" target="empty-state"></turbo-stream>
      TURBO
    end

    def filter_requests(requests)
      requests.reject do |request|
        Trainspotter.filter_request?(request.path) || Trainspotter.internal_request?(request)
      end
    end

    def filter_by_ip(requests, ip = @current_ip)
      return requests if ip.blank?
      requests.select { |request| request.ip == ip }
    end
  end
end
