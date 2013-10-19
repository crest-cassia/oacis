class JobObserver

  def self.perform(logger)
    # if @@last_updated_at and @last_updated_at - DateTime.now
    Host.all.each do |host|
      logger.info("observing jobs on #{host.name}")
      host.check_submitted_job_status
    end
  rescue => ex
    logger.error("Error in JobObserver: #{ex.inspect}")
  end

end