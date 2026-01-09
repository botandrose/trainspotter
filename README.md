# Trainspotter

A zero-config, web-based Rails log viewer with request grouping and session tracking. See your Rails logs in a beautiful, organized interface right in your browser.

## Features

- **Zero configuration** - Just mount the engine and go
- **Request grouping** - See HTTP requests with their associated SQL queries and view renders
- **Session tracking** - Group requests by user session with automatic login/logout detection
- **Real-time updates** - New requests appear automatically via polling
- **Background processing** - Log ingestion runs in a background job
- **SQLite storage** - Separate database for fast queries without impacting your app
- **Dark/light mode** - Respects your system preference
- **Performance at a glance** - See request duration, query count, and render count

## Installation

Add this line to your application's Gemfile:

```ruby
gem "trainspotter"
```

And then execute:

```bash
bundle install
```

## Usage

Mount the engine in your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount Trainspotter::Engine => "/admin/logs"

  # Your other routes...
end
```

That's it! Visit `/trainspotter` in your browser to see your logs.

### Restricting Access

In production, you'll likely want to restrict access. Here are some options:

**With Devise:**

```ruby
authenticate :user, ->(u) { u.admin? } do
  mount Trainspotter::Engine => "/trainspotter"
end
```

**With HTTP Basic Auth:**

```ruby
mount Trainspotter::Engine => "/trainspotter", constraints: ->(req) {
  Rack::Auth::Basic::Request.new(req.env).provided? &&
  Rack::Auth::Basic::Request.new(req.env).credentials == ["admin", ENV["TRAINSPOTTER_PASSWORD"]]
}
```

**Development only:**

```ruby
if Rails.env.development?
  mount Trainspotter::Engine => "/trainspotter"
end
```

## How It Works

Trainspotter reads your Rails log files and parses the standard Rails log format. A background job (`IngestJob`) processes new log entries and stores them in a separate SQLite database.

**Requests View:**
- HTTP method and path
- Controller and action
- Response status (color-coded)
- Total duration
- Number of SQL queries and view renders
- Click to expand and see SQL queries and renders

**Sessions View:**
- Groups requests by user session (based on IP + time window)
- Automatic login/logout detection
- See all requests made during a session

Trainspotter supports tagged logging (`config.log_tags = [:request_id]`) for accurate request grouping in multi-threaded environments.

## Requirements

- Rails 8.0+
- Ruby 3.3+

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/trainspotter.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
