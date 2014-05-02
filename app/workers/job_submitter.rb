class JobSubmitter

  def self.perform(logger)
    @term_received = false
    trap('TERM') {
      @term_received = true
      logger.info("TERM received by JobSubmitter. stopping")
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
      logger.info("#{num_start_process} host processes will be forked") if num_start_process > 0
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
    logger.info("JobSubmitter waits host porcess stopping")
    Process.waitall
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

  def self.host_process(host, logger)
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
          logger.info("TERM received by host #{host_id}. stopping")
        }

        begin
          Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml')) # make a new Mongo session in each process.
          loop do
            host = Host.find(host_id)
            host_process(host, logger)

            break if @term_received
            break if @term_received_host[host_id]
            sleep host.polling_interval
            break if @term_received
            break if @term_received_host[host_id]
          end
          logger.info("host process(#{host_id}) is finished")
        rescue => ex
          logger.error("Error in JobSubmitter#host_process: #{ex.inspect}")
          logger.error(ex.backtrace)
        end
      end
    end
    rescue => ex
      logger.error("Error in JobSubmitter#fork_host_process: #{ex.inspect}")
      logger.error(ex.backtrace)
    ensure
      # anyway, try to clear Mongoid session, then try to make a new Mongoid session
      Mongoid::sessions.clear
      Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml'))
    end
  end

  def self.kill_host_process(logger, host_ids)
    @host_pids.keys.select {|enabled_host_id| host_ids.include?(enabled_host_id)}.each do |kill_host_id|
      logger.info("TERM submitted to host #{kill_host_id}(#{@host_pids[kill_host_id]})")
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

