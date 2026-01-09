module Trainspotter
  class FilePositionRecord < Record
    self.table_name = "file_positions"
    self.primary_key = "log_file"

    def self.get_position(log_file)
      find_by(log_file: log_file)&.position || 0
    end

    def self.update_position(log_file, position)
      upsert(
        { log_file: log_file, position: position, updated_at: Time.current },
        unique_by: :log_file
      )
    end
  end
end
