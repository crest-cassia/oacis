class JobMonitoringWorker

  def self.perform(logger)
    Host.all.each do |host|
      begin
        host.check_submitted_job_status(logger)
      rescue => ex
        logger.error("Error in JobMonitoringWorker: #{ex.inspect}")
      end
    end
  end
end