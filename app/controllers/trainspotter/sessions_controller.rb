module Trainspotter
  class SessionsController < ApplicationController
    def index
      @current_log_file = params[:log_file] || Trainspotter.default_log_file
      @available_log_files = Trainspotter.available_log_files
      @show_anonymous = params[:show_anonymous] == "1"

      @sessions = SessionRecord.recent(
        log_file: @current_log_file,
        include_anonymous: @show_anonymous,
        limit: 50
      )
    end

    def requests
      requests = RequestRecord.for_session(params[:id], limit: 200)
      @requests = filter_requests(requests)

      render json: {
        requests: @requests.map { |r| render_to_string(partial: "trainspotter/requests/request", locals: { request: r }) }
      }
    end

    private

    def filter_requests(requests)
      requests.reject { |r| Trainspotter.filter_request?(r.path) || Trainspotter.internal_request?(r) }
    end
  end
end
