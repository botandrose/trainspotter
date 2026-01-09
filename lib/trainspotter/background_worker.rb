require "concurrent"

module Trainspotter
  class BackgroundWorker < Struct.new(:interval, :lock_path, :logger, :task_block, :timer_task, :lock_file, keyword_init: true)
    class << self
      attr_accessor :instance

      def start(interval:, lock_path:, logger: nil, &task_block)
        raise ArgumentError, "a block is required" unless task_block
        return if instance&.running?

        self.instance = new(interval:, lock_path:, logger:, task_block:)
        instance.start
      end

      def stop
        instance&.stop
        self.instance = nil
      end
    end

    def start
      return if running?
      return unless acquire_lock

      self.timer_task = Concurrent::TimerTask.new(
        execution_interval: interval,
        run_now: true,
        &task_block
      )

      timer_task.add_observer do |_time, _result, error|
        if error
          logger&.error "[Trainspotter] Background worker error: #{error.message}"
          logger&.error error.backtrace.first(10).join("\n")
        end
      end

      timer_task.execute

      logger&.info "[Trainspotter] Background worker started (pid=#{Process.pid})"
    end

    def stop
      timer_task&.shutdown
      self.timer_task = nil
      release_lock

      logger&.info "[Trainspotter] Background worker stopped"
    end

    def running?
      timer_task&.running?
    end

    private

    def acquire_lock
      self.lock_file = File.open(lock_path, File::RDWR | File::CREAT)
      lock_file.flock(File::LOCK_EX | File::LOCK_NB)
    rescue Errno::EWOULDBLOCK, Errno::EAGAIN
      lock_file&.close
      self.lock_file = nil
      false
    end

    def release_lock
      return unless lock_file
      lock_file.flock(File::LOCK_UN)
      lock_file.close
      self.lock_file = nil
    end
  end
end
