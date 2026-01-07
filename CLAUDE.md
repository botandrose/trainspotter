# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Trainspotter is a zero-config Rails engine that provides a web-based log viewer with request grouping. It parses standard Rails logs and displays HTTP requests grouped with their SQL queries and view renders.

## Commands

```bash
# Run all tests
bundle exec rspec
bundle exec cucumber

# Run a single RSpec file or example
bundle exec rspec spec/models/trainspotter/log_parser_spec.rb
bundle exec rspec spec/models/trainspotter/log_parser_spec.rb:15

# Run a single Cucumber feature
bundle exec cucumber features/viewing_logs.feature

# Lint
bin/rubocop
bin/rubocop -a  # auto-fix
```

## Architecture

This is a Rails Engine (mountable at any path, typically `/trainspotter`).

### Core Components

**Log Parsing Pipeline:**
- `LogReader` - Reads and tails log files, tracks file position for polling
- `LogParser` - Parses Rails log lines using regex patterns, groups lines into requests
- `LogEntry` - Single log line with type (`:request_start`, `:sql`, `:render`, `:request_end`, `:other`)
- `RequestGroup` - Collection of entries for one HTTP request, provides accessors for method, path, status, duration, IP, etc.

**Request Flow:**
1. `LogsController#index` loads recent requests via `LogReader`
2. JavaScript polls `LogsController#poll` for new entries
3. Filtering happens server-side: asset paths filtered by default, optional IP filtering

**Key Features:**
- `SilentRequest` middleware silences Rails logger for `/trainspotter` requests (prevents log pollution)
- `AnsiToHtml` converts ANSI color codes to styled HTML spans
- `Trainspotter.filtered_paths` - configurable regex patterns to hide (assets, packs, etc.)

### Test Structure

- `spec/dummy/` - Minimal Rails app for testing the engine
- `spec/models/trainspotter/` - Unit tests for core models
- `spec/lib/trainspotter/` - Tests for library code (filtering, middleware)
- `features/` - Cucumber acceptance tests with Capybara/Cuprite

### Configuration

```ruby
Trainspotter.log_directory = "/custom/path"  # defaults to Rails.root/log
Trainspotter.filtered_paths = [%r{^/admin/}] # replace default filters
Trainspotter.reset_filters!                   # restore defaults
```
