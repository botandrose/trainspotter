Given("a Rails log file exists") do
  @log_dir = Rails.root.join("tmp", "trainspotter_logs")
  FileUtils.mkdir_p(@log_dir)
  @log_path = @log_dir.join("test.log")
  FileUtils.touch(@log_path)

  # Configure Trainspotter to use our test log directory
  allow(Trainspotter).to receive(:log_directory).and_return(@log_dir.to_s)
end

Given("the following log files exist:") do |table|
  @log_dir = Rails.root.join("tmp", "trainspotter_logs")
  FileUtils.rm_rf(@log_dir)
  FileUtils.mkdir_p(@log_dir)

  table.hashes.each do |row|
    FileUtils.touch(@log_dir.join(row["filename"]))
  end

  @log_path = @log_dir.join("test.log")

  allow(Trainspotter).to receive(:log_directory).and_return(@log_dir.to_s)
end

Given("the log file is empty") do
  File.write(@log_path, "")
end

Given("the log file contains a GET request to {string}") do |path|
  write_request_to_log(method: "GET", path: path, status: 200)
end

Given("the log file contains a GET request to {string} with SQL queries") do |path|
  File.write(@log_path, <<~LOG)
    Started GET "#{path}" for 127.0.0.1 at 2024-01-06 10:00:00 +0000
    Processing by PostsController#index as HTML
      Post Load (0.5ms)  SELECT "posts".* FROM "posts"
      User Load (0.3ms)  SELECT "users".* FROM "users" WHERE "users"."id" = 1
      Rendered posts/index.html.erb within layouts/application (Duration: 5.0ms | GC: 0.0ms)
    Completed 200 OK in 50ms (Views: 40.0ms | ActiveRecord: 0.8ms)
  LOG
end

Given("the log file contains:") do |table|
  log_content = ""
  table.hashes.each_with_index do |row, index|
    log_content += generate_request_log(
      method: row["method"],
      path: row["path"],
      status: row["status"].to_i,
      timestamp_offset: index
    )
  end
  File.write(@log_path, log_content)
end

Given("{string} contains a GET request to {string}") do |filename, path|
  log_path = @log_dir.join(filename)
  File.write(log_path, generate_request_log(method: "GET", path: path, status: 200, timestamp_offset: 0))
end

When("I visit the trainspotter page") do
  visit "/trainspotter"
end

When("I expand the request group for {string}") do |path|
  # Text may be split across elements with newlines, so use a regex
  pattern = Regexp.new(path.split.map { |word| Regexp.escape(word) }.join('\s+'))
  find(".request-group", text: pattern).click
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("I should see a request group for {string}") do |text|
  # Text may be split across elements with newlines, so use a regex
  # that matches with flexible whitespace
  pattern = Regexp.new(text.split.map { |word| Regexp.escape(word) }.join('\s+'))
  expect(page).to have_css(".request-group", text: pattern)
end

Then("the request should show status {string}") do |status|
  expect(page).to have_css(".request-status", text: status)
end

Then("I should see the SQL queries within the request") do
  within(".request-details") do
    expect(page).to have_css(".entry-badge.sql", minimum: 1)
    expect(page).to have_content("SELECT")
  end
end

Then("I should see {int} request groups") do |count|
  expect(page).to have_css(".request-group", count: count)
end

Then("the request for {string} should have class {string}") do |path, css_class|
  expect(page).to have_css(".request-group.#{css_class}", text: path)
end

Then("the log selector should show {string} as selected") do |filename|
  expect(page).to have_select("log_file", selected: filename)
end

Then("I should see {string} in the log selector") do |filename|
  expect(page).to have_select("log_file", with_options: [ filename ])
end

Then("I should not see {string} in the log selector") do |filename|
  expect(page).not_to have_select("log_file", with_options: [ filename ])
end

When("I select {string} from the log selector") do |filename|
  select filename, from: "log_file"
end

Then("I should not see {string}") do |text|
  expect(page).not_to have_content(text)
end

def write_request_to_log(method:, path:, status:, timestamp_offset: 0)
  File.write(@log_path, generate_request_log(method: method, path: path, status: status, timestamp_offset: timestamp_offset))
end

def generate_request_log(method:, path:, status:, timestamp_offset: 0)
  timestamp = Time.new(2024, 1, 6, 10, 0, timestamp_offset).strftime("%Y-%m-%d %H:%M:%S %z")
  controller = path.gsub("/", "").capitalize + "Controller"
  action = method == "GET" ? "index" : "create"
  status_text = case status
  when 200 then "OK"
  when 302 then "Found"
  when 404 then "Not Found"
  when 500 then "Internal Server Error"
  else "Unknown"
  end

  <<~LOG
    Started #{method} "#{path}" for 127.0.0.1 at #{timestamp}
    Processing by #{controller}##{action} as HTML
    Completed #{status} #{status_text} in 50ms
  LOG
end
