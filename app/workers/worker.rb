class Worker < DaemonSpawn::Base

  # In subclass, define the following constants
  #   - INTERVAL
  #   - WORKER_PID_FILE
  #   - WORKER_LOG_FILE
  #   - WORKER_STDOUT_FILE
  #   - TASKS

  # The flag is stored on Worker itself so that subclasses and task classes
  # (JobSubmitter, JobObserver, ...) all see the same flag.
  def self.term_received?
    !!Worker.instance_variable_get(:@term_received)
  end

  def self.term_received=(val)
    Worker.instance_variable_set(:@term_received, val)
  end

  def start(args)
    @logger = LoggerForWorker.new(self.class::WORKER_ID, self.class::WORKER_LOG_FILE, 7)
    @logger.info("starting #{self.class}")

    Worker.term_received = false
    trap('TERM') {
      Worker.term_received = true
      puts "TERM received. stopping"
    }

    loop do
      self.class::TASKS.each do |task|
        begin
          task.call(@logger)
        rescue => ex
          # a failure of one task must not kill the daemon
          @logger.error("Error in #{self.class}: #{ex.inspect}")
          @logger.error(ex.backtrace)
        end
        break if Worker.term_received?
      end
      break if Worker.term_received?
      self.class::INTERVAL.times do
        break if Worker.term_received?
        sleep 1
      end
      break if Worker.term_received?
    end

  rescue => ex
    @logger&.fatal(ex.message)
    @logger&.fatal(ex.backtrace)
  ensure
    @logger&.info("stopped")
  end

  def stop
    # Never called because trap('TERM') is overwritten
  end

  def self.alive?
    if File.file?(self::WORKER_PID_FILE)
      pid = (IO.read(self::WORKER_PID_FILE).to_i)
      DaemonSpawn.alive? pid
    else
      false
    end
  end

  # return true if the time stamp of the log file is updated within five minutes
  LOG_UPDATE_THRESHOLD = 60 * 5 # 5 minutes
  def self.log_recently_updated?
    if File.file?(self::WORKER_LOG_FILE)
      s = File.stat(self::WORKER_LOG_FILE)
      return true if Time.now - s.mtime < LOG_UPDATE_THRESHOLD
    end
    false
  end
end
