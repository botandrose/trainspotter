# Trainspotter

A zero-config, web-based Rails log viewer with request grouping. See your Rails logs in a beautiful, organized interface right in your browser.

## Features

- **Zero configuration** - Just mount the engine and go
- **Request grouping** - See HTTP requests with their associated SQL queries and view renders
- **Real-time updates** - New requests appear automatically via polling
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
  mount Trainspotter::Engine => "/trainspotter"

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

Trainspotter reads your Rails log file (`log/#{Rails.env}.log`) and parses the standard Rails log format. It groups related log lines into requests based on the "Started"/"Completed" pattern.

Each request shows:
- HTTP method and path
- Controller and action
- Response status (color-coded)
- Total duration
- Number of SQL queries
- Number of view renders

Click on a request to expand it and see all the SQL queries and view renders that happened during that request.

## Requirements

- Rails 7.0+
- Ruby 3.1+

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/trainspotter.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
