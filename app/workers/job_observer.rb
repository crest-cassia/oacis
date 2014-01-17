class JobObserver

  def self.perform(logger)
    Host.all.each do |host|
      begin
        host.check_submitted_job_status(logger)
      rescue => ex
        logger.error("Error in JobObserver: #{ex.inspect}")
      end
    end
  end

  def self.observe_host
  end
end