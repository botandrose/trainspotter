Given "I am on the trainspotter page" do
  ingest_logs
  visit "/trainspotter"
end

When "I follow {string}" do |link|
  click_link link
end

When "I expand the request group for {string}" do |path|
  pattern = Regexp.new(path.split.map { |word| Regexp.escape(word) }.join('\s+'))
  find(".request-group", text: pattern).click
end

When "I expand the session for {string}" do |email|
  find(".session-group", text: email).click
end

When "I select {string} from the log selector" do |filename|
  select filename, from: "log_file"
end

When "I check {string}" do |label|
  check(label)
end

Then "I should see {string}" do |text|
  expect(page).to have_content(text)
end

Then "I should not see {string}" do |text|
  expect(page).not_to have_content(text)
end

Then "I should see a request group for {string}" do |text|
  pattern = Regexp.new(text.split.map { |word| Regexp.escape(word) }.join('\s+'))
  expect(page).to have_css(".request-group", text: pattern)
end

Then "I should see a request for {string}" do |text|
  pattern = Regexp.new(text.split.map { |word| Regexp.escape(word) }.join('\s+'))
  expect(page).to have_css(".request-group, .session-request", text: pattern)
end

Then "the request should show status {string}" do |status|
  expect(page).to have_css(".request-status", text: status)
end

Then "I should see the SQL queries within the request" do
  within(".request-details") do
    expect(page).to have_css(".entry-badge.sql", minimum: 1)
    expect(page).to have_content("SELECT")
  end
end

Then "I should see {int} request groups" do |count|
  expect(page).to have_css(".request-group", count: count)
end

Then "I should see {int} sessions" do |count|
  expect(page).to have_css(".session-group", count: count)
end

Then "the request for {string} should have class {string}" do |path, css_class|
  expect(page).to have_css(".request-group.#{css_class}", text: path)
end

Then "the log selector should show {string} as selected" do |filename|
  expect(page).to have_select("log_file", selected: filename)
end

Then "I should see {string} in the log selector" do |filename|
  expect(page).to have_select("log_file", with_options: [filename])
end

Then "I should not see {string} in the log selector" do |filename|
  expect(page).not_to have_select("log_file", with_options: [filename])
end

Then "I should see a link to {string}" do |text|
  expect(page).to have_link(text)
end
