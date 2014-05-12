module JobWorkerUtil

  # method needs 2 garguments, like method(host, logger)
  def self.perform(logger, method)
    @term_received = false
    trap('TERM') {
      @term_received = true
      logger.info("#{message_prefix(method)} TERM received. stopping")
    }

    # { "host_id1"=>"pid1", "host_id2"=>"pid2", ... }
    # host process is created: {"host_id"=>nil}
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
      logger.info("#{message_prefix(method)} #{num_start_process} host processes will be forked") if num_start_process > 0
      fork_host_process(logger, method)
      disabled_host_ids = Host.where(status: :disabled).map(&:id).map{|o| o.to_s}
      kill_host_process(logger, disabled_host_ids)

      if @term_received
        break
      else
        sleep 5 # wait 5 sec
      end
    end

    kill_host_process(logger, @host_pids.keys)
    logger.info("#{message_prefix(method)} waiting host porcess stopping")
    Process.waitall
  end

  private
  def self.fork_host_process(logger, method)
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
          logger.info("#{message_prefix(method)} TERM received for host #{host_id}. stopping")
        }

        begin
          Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml')) # make a new Mongo session in each process.
          loop do
            host = Host.find(host_id)
            method.call(host, logger)

            break if @term_received
            break if @term_received_host[host_id]
            sleep host.polling_interval
            break if @term_received
            break if @term_received_host[host_id]
          end
          logger.info("#{message_prefix(method)} host process(#{host_id}) is finished")
        rescue => ex
          logger.error("#{message_prefix(method)} Error in host_process: #{ex.inspect}")
          logger.error(ex.backtrace)
        end
      end
    end
    rescue => ex
      logger.error("#{message_prefix(method)} Error in fork_host_process: #{ex.inspect}")
      logger.error(ex.backtrace)
    ensure
      # anyway, try to clear Mongoid session, then try to make a new Mongoid session
      Mongoid::sessions.clear
      Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml'))
    end
  end

  def self.kill_host_process(logger, host_ids)
    @host_pids.keys.select {|enabled_host_id| host_ids.include?(enabled_host_id)}.each do |kill_host_id|
      Process.kill( "TERM", @host_pids[kill_host_id] )
    end
  end

  def self.check_host_process(logger)
    @host_pids.each do |host_id, pid|
      if Process.waitpid(pid, Process::WNOHANG) # No blocking mode, check process status
        @host_pids.delete(host_id)
      end
    end
  end

  def self.message_prefix(method)
    str = method.owner.to_s # "#<Class:JobSubmitter>"
    class_name = str[8..(str.length-2)]
    class_name + ":"
  end
end
