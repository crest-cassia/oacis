class JobObserver

  MAX_NUM_JOBS=20

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
      job_count=0
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
            job_counter+=1
            break if job_counter==MAX_NUM_JOBS
          end
        rescue => ex
          logger.error("Error in RemoteJobHandler#remote_status: #{ex.inspect}")
          logger.error ex.backtrace

          # When ssh connection is failed, ex.inspect="#<NoMethodError: undefined method `stat' for nil:NilClass>"
          if ex.inspect.to_s == "#<NoMethodError: undefined method `stat' for nil:NilClass>"
            logger.error("ssh connection error occurs in getting status of run:\"#{run.to_param.to_s}\"")
          else
            logger.error("run:\"#{run.to_param.to_s}\" is failed")
            if run.result.present?
              run.result = "System_message:_output.json is not stored. More detail is written in log files."
            end
            run.status = :failed
            run.save!
          end
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

