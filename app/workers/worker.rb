class Worker < DaemonSpawn::Base

  INTERVAL = 5

  def start(args)
    @logger = Logger.new(STDOUT)
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
end

if $0 == __FILE__
  Worker.spawn!(log_file: Rails.root.join('log', "worker_#{Rails.env}.log"),
                pid_file: Rails.root.join('tmp', 'pids', "worker_#{Rails.env}.pid"),
                sync_log: true,
                working_dir: Rails.root,
                singleton: true
                )
end