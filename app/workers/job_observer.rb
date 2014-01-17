class JobObserver

  def self.perform(logger)
    Host.all.each do |host|
      begin
        observe_host(host, logger)
      rescue => ex
        logger.error("Error in JobObserver: #{ex.inspect}")
      end
    end
  end

  private
  def self.observe_host(host, logger)
    # host.check_submitted_job_status(logger)
    return if host.submitted_runs.count == 0
    host.start_ssh do |ssh|
      handler = RemoteJobHandler.new(host)
      # check if job is finished
      host.submitted_runs.each do |run|
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
            JobIncluder.include_remote_job(self, run)
          end
        rescue => ex
          logger.error("Error in Host#check_submitted_job_status: #{ex.inspect}")
          logger.error ex.backtrace
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