class JobSubmitter

  def self.perform(logger)
    Host.all.each do |host|
      begin
        num = host.max_num_jobs - host.submitted_runs.count
        if num > 0
          runs = host.submittable_runs.limit(num)
          logger.info("submitting jobs to #{host.name}: #{runs.map do |r| r.id.to_s end.inspect}")
          submit(runs, host, logger)
        end
      rescue => ex
        logger.error("Error in JobSubmitter: #{ex.inspect}")
        logger.error(ex.backtrace)
      end
    end
  end

  private
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
