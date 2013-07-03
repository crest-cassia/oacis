class JobObserver

  QUEUE_NAME = :job_observer_queue
  @queue = QUEUE_NAME

  INTERVAL_IN_MINUTES = 1

  def self.perform
    # if @@last_updated_at and @last_updated_at - DateTime.now
    Host.all.each do |host|
      host.check_submitted_job_status
    end

    clear_queue
  end

  def self.clear_queue
    Resque::Job.destroy(QUEUE_NAME, self)
  end

  def self.on_failure(ex)
    clear_queue
  end
end