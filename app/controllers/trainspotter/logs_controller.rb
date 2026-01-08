module Trainspotter
  class LogsController < ApplicationController
    def index
      @current_log_file = params[:log_file] || Trainspotter.default_log_file
      @current_ip = params[:ip].presence
      @available_log_files = Trainspotter.available_log_files

      repository = LogRepository.new
      all_groups = filter_groups(repository.recent_requests(log_file: @current_log_file))
      @available_ips = repository.unique_ips(log_file: @current_log_file)
      @groups = filter_by_ip(all_groups).first(50)
    end

    def poll
      log_file = params[:log_file] || Trainspotter.default_log_file
      ip_filter = params[:ip].presence
      last_request_id = params[:last_request_id].presence

      repository = LogRepository.new
      new_groups = filter_by_ip(
        filter_groups(repository.poll_for_changes(log_file: log_file, since_request_id: last_request_id)),
        ip_filter
      )

      render json: {
        groups: new_groups.map { |g| render_group_html(g) },
        last_request_id: new_groups.last&.id
      }
    end

    private

    def render_group_html(group)
      render_to_string(partial: "trainspotter/logs/request_group", locals: { group: group })
    end

    def filter_groups(groups)
      groups.reject do |group|
        Trainspotter.filter_request?(group.path) || Trainspotter.internal_request?(group)
      end
    end

    def filter_by_ip(groups, ip = @current_ip)
      return groups if ip.blank?
      groups.select { |group| group.ip == ip }
    end
  end
end
