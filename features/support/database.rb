Before do
  @timestamp_offset = nil

  # Clean up SQLite database before each scenario by truncating tables
  # We can't delete the file because Puma server process has its own connection
  Trainspotter::Record.ensure_connected
  Trainspotter::RequestRecord.delete_all
  Trainspotter::SessionRecord.delete_all
  Trainspotter::FilePositionRecord.delete_all

  # Clean up log files
  log_dir = Rails.root.join("tmp", "trainspotter_logs")
  FileUtils.rm_rf(log_dir)
end

DatabaseCleaner.strategy = :truncation
