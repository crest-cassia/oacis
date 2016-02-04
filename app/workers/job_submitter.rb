class JobSubmitter

  def self.perform(logger)
    @last_performed_at ||= {}
    destroy_jobs_to_be_destroyed(logger)
    Host.where(status: :enabled).each do |host|
      break if $term_received
      next if DateTime.now.to_i - @last_performed_at[host.id].to_i < host.polling_interval
      begin
        num = host.max_num_jobs - host.submitted_runs.count - host.submitted_analyses.count
        prev_num = num
        Run::PRIORITY_ORDER.keys.sort.each do |priority|
          break if $term_received
          break unless num > 0
          analyses = host.submittable_analyses.where(priority: priority).order_by(:created_at.asc)
.limit(num)
          if analyses.present?
            logger.info("submitting analyses to #{host.name}: #{analyses.map do |r| r.id.to_s end.inspect}")
            num -= analyses.length  # [warning] analyses.length ignore 'limit', so 'num' can be negative.
            submit(analyses, host, logger)
          end

          break if $term_received
          break unless num > 0
          runs = host.submittable_runs.where(priority: priority).order_by(:created_at.asc)
.limit(num)
          if runs.present?
            logger.info("submitting runs to #{host.name}: #{runs.map do |r| r.id.to_s end.inspect}")
            num -= runs.length  # [warning] runs.length ignore 'limit', so 'num' can be negative.
            submit(runs, host, logger)
          end
        end
        if num == prev_num
          logger.debug("no submittable runs or analyses is found for #{host.name}")
        end
      rescue => ex
        logger.error("Error in JobSubmitter: #{ex.inspect}")
        logger.error(ex.backtrace)
      end
      @last_performed_at[host.id] = DateTime.now
    end
  end

  private
  def self.submit(submittables, host, logger)
    # call start_ssh in order to avoid establishing SSH connection for each run
    host.start_ssh do |ssh|
      handler = RemoteJobHandler.new(host)
      submittables.each do |job|
        break if $term_received
        begin
          handler.submit_remote_job(job)
        rescue => ex
          logger.error ex.inspect
          logger.error ex.backtrace
        end
      end
    end
  end

  def self.destroy_jobs_to_be_destroyed(logger)
    Run.where(status: :created, to_be_destroyed: true).each do |run|
      if run.destroyable?
        logger.info "Destroying Run #{run.id}"
        run.destroy
      else
        logger.warn("should not happen: #{job.class}:#{job.id} is not destroyable")
        run.set_lower_submittable_to_be_destroyed
      end
    end
    Analysis.where(status: :created, to_be_destroyed: true).each do |anl|
      if anl.destroyable?
        logger.info "Destroying Analysis #{anl.id}"
        anl.destroy
      else
        logger.info "Analysis #{anl.id} is not destroyable yet"
      end
    end
  end
end
