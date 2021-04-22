class JobObserver

  def self.perform(logger)
    @last_performed_at ||= {}
    unless is_enough_disk_space_left?(logger)
      logger.error("Disk space is not enough to include submitted jobs. Aborting.")
      return
    end
    Host.where(status: :enabled).each do |host|
      break if $term_received
      next if DateTime.now.to_i - @last_performed_at[host.id].to_i < host.polling_interval
      begin
        logger.debug "observing host #{host.name}"
        bm = Benchmark.measure {
          observe_host(host, logger)
        }
        logger.info "observation of #{host.name} finished in #{sprintf('%.1f', bm.real)}" if bm.real > 1.0
      rescue => ex
        logger.error("Error in JobObserver: #{ex.inspect}")
        logger.error(ex.backtrace)
      end
      @last_performed_at[host.id] = DateTime.now
    end
  end

  private
  def self.observe_host(host, logger)
    # host.check_submitted_job_status(logger)
    return if host.submitted_runs.count == 0 and host.submitted_analyses.count == 0
    host.start_ssh_shell(logger: logger) do |sh|
      logger.debug "making SSH connection to #{host.name}"
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
    logger.debug "deleting cancelled jobs #{jobs.map(&:id)}" if jobs.present?
    jobs.each do |job|
      break if $term_received
      if job.destroyable?
        logger.info("canceling remote job: #{job.class}:#{job.id} from #{host.name}")
        handler.cancel_remote_job(job)
        logger.info("canceled remote job: #{job.class}:#{job.id} from #{host.name}")
        job.destroy
        logger.info("destroyed #{job.class} #{job.id}")
      else
        logger.warn("should not happen: #{job.class}:#{job.id} is not destroyable")
        job.set_lower_submittable_to_be_destroyed
      end
    end
  end

  def self.observe_jobs(jobs, host, handler, logger)
    remote_statuses = handler.remote_status_multiple(jobs, logger) if handler.support_multiple_xstat?
    jobs.each do |job|
      break if $term_received
      remote_status = remote_statuses[job.job_id] if remote_statuses
      observe_job(job, host, handler, remote_status, logger)
    end
  end

  def self.observe_job(job, host, handler, remote_status, logger)
    if remote_status.nil?
      logger.debug("checking the job status of: #{job.class}:#{job.id}")
      remote_status = handler.remote_status(job, logger)
    end
    case remote_status
    when :submitted
      logger.debug("status for #{job.class}:#{job.id} is 'submitted'")
      # DO NOTHING
    when :running
      logger.debug("status for #{job.class}:#{job.id} is 'running'")
      if job.status == :submitted then
        job.update_attribute(:status, :running)
        StatusChannel.broadcast_to('message', OacisChannelUtil.createJobStatusMessage(job))
      end
    when :includable, :unknown
      logger.info("including #{job.class}:#{job.id} from #{host.name}")
      JobIncluder.include_remote_job(host, job, logger)
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
      logger.error("not enough space left on device.")
    elsif rate > 0.9
      logger.warn("little space left on device.")
    end
    b
  end
end
