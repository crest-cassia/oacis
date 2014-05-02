class JobObserver

  def self.perform(logger)
    @term_received = false
    trap('TERM') {
      @term_received = true
      logger.info("TERM received by JobObserver. stopping")
    }

    # { "host_id1"=>"pid1", "host_id2"=>"pid2", ... }
    # host process will be created: {"host_id"=>nil}
    # host process is running: {"host_id"=>"pid"}
    # host process is stopping: {"host_id"=>"pid"}
    # host process is stopped: {}
    @host_pids = {}
    loop do
      check_host_process(logger)
      Host.where(status: :enabled).each do |host|
        @host_pids[host.to_param] ||= nil
      end
      num_start_process = @host_pids.values.select {|v| v.nil?}.length
      logger.info("JobObserver: #{num_start_process} host processes will be forked") if num_start_process > 0
      fork_host_process(logger)
      disabled_host_ids = Host.where(status: :disabled).map(&:id).map{|o| o.to_s}
      kill_host_process(logger, disabled_host_ids)

      if @term_received
        break
      else
        sleep 5 # wait 5 sec
      end
    end

    kill_host_process(logger, @host_pids.keys)
    logger.info("JobObserver: waiting host porcess stopping")
    Process.waitall
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

  def self.fork_host_process(logger)
    Mongoid::sessions.clear # before forking a process, clear Mongo session. Otherwise, invalid data may be obtained.
    begin
    @host_pids.each do |host_id, pid|
      next unless pid.nil?
      @host_pids[host_id] = fork do
        logger.info("#{host_id} host process is forked")
        @term_received_host ||= {}
        @term_received_host[host_id] = false
        trap('TERM') {
          @term_received_host[host_id] = true
          logger.info("JobObserver: TERM received by host #{host_id}. stopping")
        }

        begin
          Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml')) # make a new Mongo session in each process.
          loop do
            host = Host.find(host_id)
            observe_host(host, logger)

            break if @term_received
            break if @term_received_host[host_id]
            sleep host.polling_interval
            break if @term_received
            break if @term_received_host[host_id]
          end
          logger.info("JobObserver: host process(#{host_id}) is finished")
        rescue => ex
          logger.error("Error in JobObserver#host_process: #{ex.inspect}")
          logger.error(ex.backtrace)
        end
      end
    end
    rescue => ex
      logger.error("Error in JobObserver#fork_host_process: #{ex.inspect}")
      logger.error(ex.backtrace)
    ensure
      # anyway, try to clear Mongoid session, then try to make a new Mongoid session
      Mongoid::sessions.clear
      Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml'))
    end
  end

  def self.kill_host_process(logger, host_ids)
    @host_pids.keys.select {|enabled_host_id| host_ids.include?(enabled_host_id)}.each do |kill_host_id|
      logger.info("JobObserver: TERM submitted to host #{kill_host_id}(#{@host_pids[kill_host_id]})")
      Process.kill( "TERM", @host_pids[kill_host_id] )
    end
  end

  def self.check_host_process(logger)
    @host_pids.each do |host_id, pid|
      if Process.waitpid(pid, Process::WNOHANG) # No blocking mode
        @host_pids.delete(host_id)
      end
    end
  end
end

