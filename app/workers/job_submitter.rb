class JobSubmitter

  def self.perform(logger)
    Host.all.each do |host|
      num = host.max_num_jobs - host.submitted_runs.count
      if num > 0
        runs = host.submittable_runs.limit(num)
        logger.info("submitting jobs to #{host.name}: #{runs.map do |r| r.id.to_s end.inspect}")
        host.submit(runs)
      end
    end
  rescue => ex
    logger.error("Error in JobSubmitter: #{ex.inspect}")
  end
end
