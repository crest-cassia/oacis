class JobSubmitter

  def self.perform(logger)
    JobWorkerUtil.perform(logger, JobSubmitter.method(:submit_runs))
  end

  private
  def self.submit_runs(host, logger)
    num = host.max_num_jobs - host.submitted_runs.count
    if num > 0
      submitted_runs = []
      Run::PRIORITY_ORDER.keys.sort.each do |priority|
        runs = host.submittable_runs.where(priority: priority).limit(num)
        num -= runs.length
        submitted_runs += runs.map do |r| r.id.to_s end
        submit(runs, host, logger)
        break if num == 0
      end
      logger.info("submitting jobs to #{host.name}: #{submitted_runs.inspect}")
    end
  end

  def self.submit(runs, host, logger)
    # call start_ssh in order to avoid establishing SSH connection for each run
    host.start_ssh do |ssh|
      handler = RemoteJobHandler.new(host)
      runs.each do |run|
        begin
          handler.submit_remote_job(run)
        rescue => ex
          logger.info ex.inspect
          logger.info ex.backtrace
        end
      end
    end
  end
end

