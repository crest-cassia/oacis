class Worker < DaemonSpawn::Base

  # In subclass, define the following constants
  #   - INTERVAL
  #   - WORKER_PID_FILE
  #   - WORKER_LOG_FILE
  #   - WORKER_STDOUT_FILE
  #   - TASKS

  def start(args)
    @logger = LoggerForWorker.new(self.class::WORKER_ID, self.class::WORKER_LOG_FILE, 7)
    @logger.info("starting #{self.class}")

    $term_received = false
    trap('TERM') {
      $term_received = true
      puts "TERM received. stopping"
    }

    loop do
      self.class::TASKS.each do |task|
        task.call(@logger)
        break if $term_received
      end
      sleep self.class::INTERVAL
      break if $term_received
    end

  rescue => ex
    @logger.fatal(ex.message)
    @logger.fatal(ex.backtrace)
  ensure
    @logger.info("stopped")
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

