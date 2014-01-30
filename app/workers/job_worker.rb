class JobWorker < DaemonSpawn::Base

  INTERVAL = 5

  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "job_worker_#{Rails.env}.pid")
  WORKER_LOG_FILE = Rails.root.join('log', "job_worker_#{Rails.env}.log")

  def start(args)
    @logger = Logger.new(STDOUT, 7)
    @logger.level = Logger::INFO
    @logger.info("starting")

    @term_received = false
    trap('TERM') {
      @term_received = true
      @logger.info("TERM received. stopping")
    }

    loop do
      JobSubmitter.perform(@logger)
      break if @term_received
      JobObserver.perform(@logger)
      break if @term_received
      sleep INTERVAL
      break if @term_received
    end

    @logger.info("stopped")
  end

  def stop
    @logger.info("stopping")
  end

  def self.alive?
    if File.file?(WORKER_PID_FILE)
      pid = (IO.read(WORKER_PID_FILE).to_i)
      DaemonSpawn.alive? pid
    else
      false
    end
  end

  # return true if the time stamp of the log file is updated within five minutes
  LOG_UPDATE_THRESHOLD = 60 * 5 # 5 minutes
  def self.log_recently_updated?
    if File.file?(WORKER_LOG_FILE)
      s = File.stat(WORKER_LOG_FILE)
      return true if Time.now - s.mtime < LOG_UPDATE_THRESHOLD
    end
    false
  end
end

if $0 == __FILE__
  JobWorker.spawn!(log_file: JobWorker::WORKER_LOG_FILE,
                pid_file: JobWorker::WORKER_PID_FILE,
                sync_log: true,
                working_dir: Rails.root,
                singleton: true
                )
end
