class Worker < DaemonSpawn::Base

  INTERVAL = 5

  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "worker_#{Rails.env}.pid")
  WORKER_LOG_FILE = Rails.root.join('log', "worker_#{Rails.env}.log")

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
      AnalyzerRunner.perform(@logger)
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
end

if $0 == __FILE__
  Worker.spawn!(log_file: Worker::WORKER_LOG_FILE,
                pid_file: Worker::WORKER_PID_FILE,
                sync_log: true,
                working_dir: Rails.root,
                singleton: true
                )
end