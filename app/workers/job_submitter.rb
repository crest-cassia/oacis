class JobSubmitter

  QUEUE_NAME = :job_submitter_queue
  @queue = QUEUE_NAME

  INTERVAL_IN_MINUTES = 1

  def self.perform
    Host.all.each do |host|
      num = host.max_num_jobs - host.submitted_runs.count
      num = 0 if num < 0
      runs = host.submittable_runs.limit(num)
      host.submit(runs)
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
