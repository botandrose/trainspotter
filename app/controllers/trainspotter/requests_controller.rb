module Trainspotter
  class RequestsController < ApplicationController
    def index
      @current_log_file = params[:log_file] || Trainspotter.default_log_file
      @current_ip = params[:ip].presence
      @available_log_files = Trainspotter.available_log_files

      all_requests = filter_requests(RequestRecord.recent(log_file: @current_log_file))
      @available_ips = RequestRecord.unique_ips(log_file: @current_log_file)
      @requests = filter_by_ip(all_requests).first(50)
    end

    def poll
      log_file = params[:log_file] || Trainspotter.default_log_file
      ip_filter = params[:ip].presence
      since_id = params[:since_id].presence

      new_requests = filter_by_ip(
        filter_requests(RequestRecord.poll_for_changes(log_file: log_file, since_id: since_id)),
        ip_filter
      )

      render json: {
        requests: new_requests.map { |r| render_request_html(r) },
        since_id: new_requests.last&.id
      }
    end

    private

    def render_request_html(request)
      render_to_string(partial: "trainspotter/requests/request", locals: { request: request })
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
