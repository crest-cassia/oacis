class JobObserver

  def self.perform(logger)
    @last_performed_at ||= {}
    Host.where(status: :enabled).each do |host|
      break if $term_received
      next if DateTime.now.to_i - @last_performed_at[host.id].to_i < host.polling_interval
      begin
        logger.info("observing #{host.name}")
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
      host.submitted_runs.each do |run|
        break if $term_received
        observe_job(run, host, handler, logger)
      end
      host.submitted_analyses.each do |anl|
        break if $term_received
        observe_job(anl, host, handler, logger)
      end
    end
  end

  def self.observe_job(job, host, handler, logger)
    if job.status == :cancelled
      logger.info("canceling remote job: #{job.class}:#{job.id} from #{host.name}")
      handler.cancel_remote_job(job)
      logger.info("canceled remote job: #{job.class}:#{job.id} from #{host.name}")
      job.destroy(true)
      logger.info("removed from DB")
      return
    end
    case handler.remote_status(job)
    when :submitted
      # DO NOTHING
    when :running
      if job.status == :submitted
        current_stat = job.class.find(job.id).status
        if current_stat == :submitted
          job.update_attribute(:status, :running)
        elsif current_stat == :cancelled
          logger.info("job #{job.id} was canceled while checking remote status")
        end
      end
    when :includable, :unknown
      logger.info("including #{job.class}:#{job.id} from #{host.name}")
      if job.class.find(job.id).status == :cancelled
        logger.info("job #{job.id} was canceled while checking remote status")
      else
        JobIncluder.include_remote_job(host, job)
      end
    end
  rescue => ex
    logger.error("Error in RemoteJobHandler#remote_status: #{ex.inspect}")
    logger.error ex.backtrace
  end

  def self.is_enough_disk_space_left?(logger)
    stat= Sys::Filesystem.stat(ResultDirectory.root.to_s)
    rate = 1.0 - stat.blocks_available.to_f / stat.blocks.to_f
    b = true
    if rate > 0.95
      b = false
      logger.error("Error: No enough space left on device.")
    elsif rate > 0.9
      logger.warn("Warn: Too little space left on device.")
    end
    b
  end
end

