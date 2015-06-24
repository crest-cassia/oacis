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
    return if host.submitted_runs.count == 0
    return unless is_enough_disk_space_left?(logger)
    host.start_ssh do |ssh|
      handler = RemoteJobHandler.new(host)
      # check if job is finished
      host.submitted_runs.each do |run|
        break if $term_received
        begin
          if run.status == :cancelled
            handler.cancel_remote_job(run)
            run.destroy(true)
            next
          end
          case handler.remote_status(run)
          when :submitted
            # DO NOTHING
          when :running
            run.update_attribute(:status, :running) if run.status == :submitted
          when :includable, :unknown
            JobIncluder.include_remote_job(host, run)
          end
        rescue => ex
          logger.error("Error in RemoteJobHandler#remote_status: #{ex.inspect}")
          logger.error ex.backtrace
        end
      end
    end
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

