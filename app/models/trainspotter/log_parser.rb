module Trainspotter
  class LogParser
    # Pattern to extract request ID tag from tagged logger output
    # e.g., "[5de6cb4c-4a8e-4d87-bafd-3ce2281e26f4] Started GET..."
    # or "  [req-id] Post Load (0.5ms)..." (tag after leading whitespace)
    TAG_PATTERN = /^(?<leading_space>\s*)\[(?<request_id>[^\]]+)\]\s*/

    # Regex patterns for Rails log formats
    PATTERNS = {
      # Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
      request_start: /^Started (?<method>GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) "(?<path>[^"]+)" for (?<ip>[\d.]+) at (?<timestamp>.+)$/,

      # Processing by PostsController#index as HTML
      # Also handles namespaced controllers like Trainspotter::LogsController
      processing: /^Processing by (?<controller>[\w:]+)#(?<action>\w+) as (?<format>\w+|\*\/\*)/,

      # Post Load (0.5ms)  SELECT "posts".* FROM "posts"
      sql: /^\s*(?<name>[\w\s]+) \((?<duration>[\d.]+)ms\)\s+(?<query>.+)$/,

      # Rendered posts/index.html.erb within layouts/application (Duration: 5.0ms | GC: 0.0ms)
      render: /^\s*Rendered (?<template>[^\s]+)(?: within (?<layout>[^\s]+))? \(Duration: (?<duration>[\d.]+)ms/,

      # Completed 200 OK in 50ms (Views: 40.0ms | ActiveRecord: 5.0ms | Allocations: 1234)
      request_end: /^Completed (?<status>\d+) .+ in (?<duration>[\d.]+)ms/
    }.freeze

    def initialize
      @groups_by_id = {}
      @current_untagged_group = nil
      @groups = []
    end

    def parse_line(line)
      line = sanitize_encoding(line.chomp)
      return nil if line.strip.empty?

      request_id, content = extract_tag(line)
      entry = identify_entry(content)

      if request_id
        handle_tagged_entry(request_id, entry)
      else
        handle_untagged_entry(entry)
      end

      entry
    end

    def parse_file(path, limit: nil)
      reset_state

      File.foreach(path).with_index do |line, index|
        break if limit && index >= limit
        parse_line(line)
      end

      finalize_all_groups
      @groups
    end

    def parse_lines(lines)
      reset_state

      lines.each { |line| parse_line(line) }

      finalize_all_groups
      @groups
    end

    def groups
      @groups.dup
    end

    private

    def reset_state
      @groups = []
      @groups_by_id = {}
      @current_untagged_group = nil
    end

    def extract_tag(line)
      if (match = line.match(TAG_PATTERN))
        leading_space = match[:leading_space] || ""
        content = leading_space + line.sub(TAG_PATTERN, "")
        [ match[:request_id], content ]
      else
        [ nil, line ]
      end
    end

    def handle_tagged_entry(request_id, entry)
      case entry.type
      when :request_start
        @groups_by_id[request_id] = RequestGroup.new(id: request_id)
        @groups_by_id[request_id] << entry
      when :request_end
        if (group = @groups_by_id[request_id])
          group << entry
          group.completed = true
          @groups << group
          @groups_by_id.delete(request_id)
        end
      else
        @groups_by_id[request_id]&.<<(entry)
      end
    end

    def handle_untagged_entry(entry)
      case entry.type
      when :request_start
        finalize_untagged_group
        @current_untagged_group = RequestGroup.new
        @current_untagged_group << entry
      when :request_end
        if @current_untagged_group
          @current_untagged_group << entry
          @current_untagged_group.completed = true
          finalize_untagged_group
        end
      else
        @current_untagged_group << entry if @current_untagged_group
      end
    end

    def finalize_untagged_group
      if @current_untagged_group&.entries&.any?
        @groups << @current_untagged_group
      end
      @current_untagged_group = nil
    end

    def finalize_all_groups
      finalize_untagged_group
      @groups_by_id.each_value do |group|
        @groups << group if group.entries.any?
      end
      @groups_by_id = {}
    end

    def identify_entry(line)
      PATTERNS.each do |type, pattern|
        if (match = line.match(pattern))
          return build_entry(line, type, match)
        end
      end

      LogEntry.new(raw: line, type: :other)
    end

    def build_entry(line, type, match)
      metadata = match.named_captures.transform_keys(&:to_sym)

      case type
      when :request_start
        timestamp = parse_timestamp(metadata[:timestamp])
        LogEntry.new(raw: line, type: type, timestamp: timestamp, metadata: metadata)
      when :processing
        LogEntry.new(raw: line, type: type, metadata: metadata)
      when :sql
        metadata[:duration_ms] = metadata.delete(:duration).to_f
        LogEntry.new(raw: line, type: type, metadata: metadata)
      when :render
        metadata[:duration_ms] = metadata.delete(:duration).to_f
        LogEntry.new(raw: line, type: type, metadata: metadata)
      when :request_end
        metadata[:status] = metadata[:status].to_i
        metadata[:duration_ms] = metadata.delete(:duration).to_f
        LogEntry.new(raw: line, type: type, metadata: metadata)
      else
        LogEntry.new(raw: line, type: type, metadata: metadata)
      end
    end

    def parse_timestamp(str)
      Time.parse(str)
    rescue ArgumentError
      nil
    end

    def sanitize_encoding(str)
      str.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end
  end
end
