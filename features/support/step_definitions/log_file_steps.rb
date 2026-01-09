Given "a Rails log file exists" do
  self.log_dir = Rails.root.join("tmp", "trainspotter_logs")
  FileUtils.mkdir_p(log_dir)
  self.log_path = log_dir.join("test.log")
  FileUtils.touch(log_path)

  allow(Trainspotter.configuration).to receive(:log_directory).and_return(log_dir.to_s)
end

Given "the following log files exist:" do |table|
  self.log_dir = Rails.root.join("tmp", "trainspotter_logs")
  FileUtils.rm_rf(log_dir)
  FileUtils.mkdir_p(log_dir)

  table.hashes.each do |row|
    FileUtils.touch(log_dir.join(row["filename"]))
  end

  self.log_path = log_dir.join("test.log")

  allow(Trainspotter.configuration).to receive(:log_directory).and_return(log_dir.to_s)
end

Given "the log file is empty" do
  write_to_log("")
end

Given "{string} contains a GET request to {string}" do |filename, path|
  file_path = log_dir.join(filename)
  File.write(file_path, generate_request_log(method: "GET", path: path, status: 200))
end
