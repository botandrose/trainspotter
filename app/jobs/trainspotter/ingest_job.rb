module Trainspotter
  class IngestJob
    def perform
      log_paths = Trainspotter.available_log_files.map do |f|
        File.join(Trainspotter.log_directory, f)
      end
      Trainspotter::Ingest::Processor.call(log_paths)
    end
  end
end
