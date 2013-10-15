class Worker < DaemonSpawn::Base

  INTERVAL = 5

  def start(args)
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.info("starting")

    loop do
      JobSubmitter.perform(@logger)
      JobObserver.perform(@logger)
      AnalyzerRunner.perform(@logger)
      sleep INTERVAL
    end
  end

  def stop
    @logger.info("stopping")
  end
end

Worker.spawn!(log_file: Rails.root.join('log', "worker_#{Rails.env}.log"),
              pid_file: Rails.root.join('tmp', 'pids', "worker_#{Rails.env}.pid"),
              sync_log: true,
              working_dir: Rails.root
              )
