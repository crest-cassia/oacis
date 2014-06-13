class JobSubmitter

  def self.perform(logger)
    @last_performed_at ||= {}
    Host.where(status: :enabled).each do |host|
      break if $term_received
      next if DateTime.now.to_i - @last_performed_at[host.id].to_i < host.polling_interval
      begin
        num = host.max_num_jobs - host.submitted_runs.count
        if num > 0
          Run::PRIORITY_ORDER.keys.sort.each do |priority|
            break if $term_received
            runs = host.submittable_runs.where(priority: priority).limit(num)
            logger.info("submitting jobs to #{host.name}: #{runs.map do |r| r.id.to_s end.inspect}")
            num -= runs.length
            submit(runs, host, logger)
            break if num == 0
          end
        end
      rescue => ex
        logger.error("Error in JobSubmitter: #{ex.inspect}")
        logger.error(ex.backtrace)
      end
      @last_performed_at[host.id] = DateTime.now
    end
  end

  private
  def self.submit(runs, host, logger)
    # call start_ssh in order to avoid establishing SSH connection for each run
    host.start_ssh do |ssh|
      handler = RemoteJobHandler.new(host)
      runs.each do |run|
        break if $term_received
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
