class JobSubmitter

  MAX_NUM_JOBS=20

  def self.perform(logger)
    @last_performed_at ||= {}
    Host.where(status: :enabled).each do |host|
      break if $term_received
      begin
        num = host.max_num_jobs - host.submitted_runs.count
        Run::PRIORITY_ORDER.keys.sort.each do |priority|
          break if $term_received
          break unless num > 0
          num=MAX_NUM_JOBS if num > MAX_NUM_JOBS
          runs = host.submittable_runs.where(priority: priority).limit(num)
          logger.info("submitting jobs to #{host.name}: #{runs.map do |r| r.id.to_s end.inspect}")
          num -= runs.length  # [warining] runs.length ignore 'limit', so 'num' can be negative.
          submit(runs, host, logger) if runs.present?
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
