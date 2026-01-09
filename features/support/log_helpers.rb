module LogHelpers
  def log_dir
    @log_dir ||= Rails.root.join("tmp", "trainspotter_logs")
  end

  def log_path
    @log_path ||= log_dir.join("test.log")
  end

  attr_writer :log_dir, :log_path

  def next_timestamp_offset
    @timestamp_offset ||= 0
    current = @timestamp_offset
    @timestamp_offset += 1
    current
  end

  def generate_request_log(method:, path:, status:, ip: "127.0.0.1", timestamp: nil)
    timestamp ||= Time.new(2024, 1, 6, 10, 0, next_timestamp_offset).strftime("%Y-%m-%d %H:%M:%S %z")
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
      Started #{method} "#{path}" for #{ip} at #{timestamp}
      Processing by #{controller}##{action} as HTML
      Completed #{status} #{status_text} in 50ms
    LOG
  end

  def generate_login_log(email:, ip:, timestamp: nil)
    timestamp ||= Time.new(2024, 1, 6, 10, 0, next_timestamp_offset).strftime("%Y-%m-%d %H:%M:%S %z")

    <<~LOG
      Started POST "/session" for #{ip} at #{timestamp}
      Processing by SessionsController#create as HTML
        Parameters: {"session"=>{"email"=>"#{email}", "password"=>"[FILTERED]"}}
        User Load (0.5ms)  SELECT "users".* FROM "users" WHERE "users"."email" = '#{email}' LIMIT 1
      Completed 302 Found in 50ms
    LOG
  end

  def generate_logout_log(ip:, timestamp: nil)
    timestamp ||= Time.new(2024, 1, 6, 10, 0, next_timestamp_offset).strftime("%Y-%m-%d %H:%M:%S %z")

    <<~LOG
      Started DELETE "/session" for #{ip} at #{timestamp}
      Processing by SessionsController#destroy as HTML
      Completed 302 Found in 10ms
    LOG
  end

  def append_to_log(content)
    File.open(log_path, "a") { |f| f.write(content) }
  end

  def write_to_log(content)
    File.write(log_path, content)
  end

  def ingest_logs
    Trainspotter::IngestJob.new.perform
  end
end

World(LogHelpers)
