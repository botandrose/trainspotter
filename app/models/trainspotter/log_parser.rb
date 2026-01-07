module Trainspotter
  class LogParser
    # Regex patterns for Rails log formats
    PATTERNS = {
      # Started GET "/posts" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
      request_start: /^Started (?<method>GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) "(?<path>[^"]+)" for (?<ip>[\d.]+) at (?<timestamp>.+)$/,

      # Processing by PostsController#index as HTML
      processing: /^Processing by (?<controller>\w+)#(?<action>\w+) as (?<format>\w+)/,

      # Post Load (0.5ms)  SELECT "posts".* FROM "posts"
      sql: /^\s+(?<name>[\w\s]+) \((?<duration>[\d.]+)ms\)\s+(?<query>.+)$/,

      # Rendered posts/index.html.erb within layouts/application (Duration: 5.0ms | GC: 0.0ms)
      render: /^\s+Rendered (?<template>[^\s]+)(?: within (?<layout>[^\s]+))? \(Duration: (?<duration>[\d.]+)ms/,

      # Completed 200 OK in 50ms (Views: 40.0ms | ActiveRecord: 5.0ms | Allocations: 1234)
      request_end: /^Completed (?<status>\d+) .+ in (?<duration>[\d.]+)ms/
    }.freeze

    def initialize
      @current_group = nil
      @groups = []
    end

    def parse_line(line)
      line = sanitize_encoding(line.chomp)
      return nil if line.strip.empty?

      entry = identify_entry(line)

      case entry.type
      when :request_start
        finalize_current_group
        @current_group = RequestGroup.new
        @current_group << entry
      when :request_end
        if @current_group
          @current_group << entry
          @current_group.completed = true
          finalize_current_group
        end
      else
        @current_group << entry if @current_group
      end

      entry
    end

    def parse_file(path, limit: nil)
      @groups = []
      @current_group = nil

      File.foreach(path).with_index do |line, index|
        break if limit && index >= limit
        parse_line(line)
      end

      finalize_current_group
      @groups
    end

    def parse_lines(lines)
      @groups = []
      @current_group = nil

      lines.each { |line| parse_line(line) }

      finalize_current_group
      @groups
    end

    def groups
      @groups.dup
    end

    private

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

    def finalize_current_group
      if @current_group && @current_group.entries.any?
        @groups << @current_group
      end
      @current_group = nil
    end

    def sanitize_encoding(str)
      str.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end
  end
end
