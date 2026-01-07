module Trainspotter
  class LogsController < ApplicationController
    def index
      @current_log_file = params[:log_file] || Trainspotter.default_log_file
      @current_ip = params[:ip].presence
      @available_log_files = Trainspotter.available_log_files
      @reader = LogReader.new(@current_log_file)
      all_groups = filter_groups(@reader.read_recent(limit: 100))
      @available_ips = extract_unique_ips(all_groups)
      @groups = filter_by_ip(all_groups).last(50).reverse
    end

    def poll
      log_file = params[:log_file] || Trainspotter.default_log_file
      ip_filter = params[:ip].presence
      reader = LogReader.new(log_file)
      position = params[:position].to_i

      if position > 0
        reader.instance_variable_set(:@file_position, position)
      end

      new_groups = filter_by_ip(filter_groups(reader.poll_for_changes), ip_filter)
      new_position = reader.instance_variable_get(:@file_position)

      render json: {
        groups: new_groups.map { |g| render_group_html(g) },
        position: new_position
      }
    end

    private

    def render_group_html(group)
      render_to_string(partial: "trainspotter/logs/request_group", locals: { group: group })
    end

    def filter_groups(groups)
      groups.reject { |group| Trainspotter.filter_request?(group.path) }
    end

    def filter_by_ip(groups, ip = @current_ip)
      return groups if ip.blank?
      groups.select { |group| group.ip == ip }
    end

    def extract_unique_ips(groups)
      groups.map(&:ip).compact.uniq.sort
    end
  end
end
