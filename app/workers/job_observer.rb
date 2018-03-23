class JobObserver

  def self.perform(logger)
    @last_performed_at ||= {}
    Host.where(status: :enabled).each do |host|
      break if $term_received
      next if DateTime.now.to_i - @last_performed_at[host.id].to_i < host.polling_interval
      logger.debug("observing #{host.name}")
      begin
        observe_host(host, logger)
      rescue => ex
        logger.error("Error in JobObserver: #{ex.inspect}")
      end
      @last_performed_at[host.id] = DateTime.now
    end
  end

  private
  def self.observe_host(host, logger)
    # host.check_submitted_job_status(logger)
    return if host.submitted_runs.count == 0 and host.submitted_analyses.count == 0
    return unless is_enough_disk_space_left?(logger)
    host.start_ssh do |ssh|
      handler = RemoteJobHandler.new(host)
      # check if job is finished
      cancelled_runs = host.submitted_runs.where(to_be_destroyed: true)
      destroy_jobs(cancelled_runs, host, handler, logger)

      submitted_runs = host.submitted_runs.where(to_be_destroyed: false)
      observe_jobs(submitted_runs, host, handler, logger)

      cancelled_analyses = host.submitted_analyses.where(to_be_destroyed: true)
      destroy_jobs(cancelled_analyses, host, handler, logger)

      submitted_analyses = host.submitted_analyses.where(to_be_destroyed: false)
      observe_jobs(submitted_analyses, host, handler, logger)

    end
  end

  def self.destroy_jobs(jobs, host, handler, logger)
    jobs.each do |job|
      break if $term_received
      if job.destroyable?
        logger.info("canceling remote job: #{job.class}:#{job.id} from #{host.name}")
        handler.cancel_remote_job(job)
        logger.info("canceled remote job: #{job.class}:#{job.id} from #{host.name}")
        job.destroy
        logger.info("destroyed #{job.class} #{job.id}")
        StatusChannel.broadcast_to('message', OacisChannelUtil.createJobStatusMessage(job, "destroyed")) if job.instance_of?(Run)
        return
      else
        logger.warn("should not happen: #{job.class}:#{job.id} is not destroyable")
        job.set_lower_submittable_to_be_destroyed
      end
    end
  end

  def self.observe_jobs(jobs, host, handler, logger)
    jobs.each do |job|
      break if $term_received
      observe_job(job, host, handler, logger)
    end
  end

  def self.observe_job(job, host, handler, logger)
    case handler.remote_status(job)
    when :submitted
      # DO NOTHING
    when :running
      if job.status == :submitted then
        job.update_attribute(:status, :running)
        StatusChannel.broadcast_to('message', OacisChannelUtil.createJobStatusMessage(job)) if job.instance_of?(Run)
      end
    when :includable, :unknown
      logger.info("including #{job.class}:#{job.id} from #{host.name}")
      JobIncluder.include_remote_job(host, job)
    end
  rescue => ex
    logger.error("Error in RemoteJobHandler#remote_status: #{ex.inspect}")
    logger.error ex.backtrace
  end

  def self.is_enough_disk_space_left?(logger)
    FileUtils.mkdir_p( ResultDirectory.root ) # to assure the existence of the result dir
    rate = DiskSpaceChecker.rate
    b = true
    if rate > 0.95
      b = false
      logger.error("no enough space left on device.")
    elsif rate > 0.9
      logger.warn("little space left on device.")
    end
    b
  end
end
