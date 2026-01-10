# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Trainspotter is a zero-config Rails engine that provides a web-based log viewer with request grouping and session tracking. It parses standard Rails logs and displays HTTP requests grouped with their SQL queries and view renders, and can group requests into user sessions.

## Commands

```bash
# Run all tests
bundle exec rspec
bundle exec cucumber

# Run a single RSpec file or example
bundle exec rspec spec/models/trainspotter/ingest/parser_spec.rb
bundle exec rspec spec/models/trainspotter/ingest/parser_spec.rb:15

# Run a single Cucumber feature
bundle exec cucumber features/viewing_logs.feature

## Architecture

This is a Rails Engine (mountable at any path, typically `/trainspotter`).

### Database

Trainspotter uses a separate SQLite database (`tmp/trainspotter.sqlite3`) to avoid impacting the main application. The `Record` base class handles connection management and schema creation using Rails conventions (`schema_migrations` table for versioning).

### Core Components

**Ingest Pipeline (`app/jobs/trainspotter/ingest/`):**
- `IngestJob` - Background job that triggers log processing
- `Processor` - Reads log files from last position, parses lines, persists to database
- `Parser` - Parses Rails log lines using regex patterns, groups lines into requests
- `Line` - Single log line with type (`:request_start`, `:sql`, `:render`, `:request_end`, `:other`)
- `SessionBuilder` - Groups requests into sessions by IP, detects login/logout

**Models (`app/models/trainspotter/`):**
- `Record` - Abstract base class, manages SQLite connection and schema
- `RequestRecord` - Persisted request with entries, status, duration, etc.
- `SessionRecord` - User session (group of requests by IP within time window)
- `FilePositionRecord` - Tracks read position in each log file
- `Request` - In-memory request during parsing (not persisted directly)

**Controllers:**
- `RequestsController` - Lists requests, handles polling for new entries
- `SessionsController` - Lists sessions, shows session details

### Request Flow

1. `IngestJob` runs periodically or on-demand
2. `Processor` reads new lines from log file, uses `Parser` to group into requests
3. `RequestRecord.upsert_from_request` persists each request
4. `SessionBuilder` assigns requests to sessions, detects login/logout
5. `RequestsController#index` loads recent requests from database
6. JavaScript polls `RequestsController#poll` for new entries via `since_id`

### Test Structure

- `spec/dummy/` - Minimal Rails app for testing the engine
- `spec/models/trainspotter/` - Unit tests for models and ingest pipeline
- `features/` - Cucumber acceptance tests with Capybara/Cuprite

### Configuration

```ruby
Trainspotter.log_directory = "/custom/path"  # defaults to Rails.root/log
Trainspotter.filtered_paths = [%r{^/admin/}] # replace default filters
Trainspotter.session_timeout = 30.minutes    # session inactivity timeout
```
