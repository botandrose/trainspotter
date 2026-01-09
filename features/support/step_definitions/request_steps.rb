Given "the log file contains a GET request to {string}" do |path|
  write_to_log(generate_request_log(method: "GET", path: path, status: 200))
end

Given "the log file contains a GET request to {string} with SQL queries" do |path|
  write_to_log(<<~LOG)
    Started GET "#{path}" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
    Processing by PostsController#index as HTML
      Post Load (0.5ms)  SELECT "posts".* FROM "posts"
      User Load (0.3ms)  SELECT "users".* FROM "users" WHERE "users"."id" = 1
      Rendered posts/index.html.erb within layouts/application (Duration: 5.0ms | GC: 0.0ms)
    Completed 200 OK in 50ms (Views: 40.0ms | ActiveRecord: 0.8ms)
  LOG
end

Given "the log file contains:" do |table|
  log_content = ""
  table.hashes.each do |row|
    log_content += generate_request_log(
      method: row["method"],
      path: row["path"],
      status: row["status"].to_i
    )
  end
  write_to_log(log_content)
end

Given "the log file contains a GET request to {string} from {string}" do |path, ip|
  append_to_log(generate_request_log(method: "GET", path: path, status: 200, ip: ip))
end

Given "the log file contains a GET request to {string} from {string} at {string}" do |path, ip, timestamp|
  append_to_log(generate_request_log(method: "GET", path: path, status: 200, ip: ip, timestamp: timestamp))
end
