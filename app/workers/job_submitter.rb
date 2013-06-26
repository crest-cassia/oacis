class JobSubmitter

  QUEUE_NAME = :job_submitter_queue
  @queue = QUEUE_NAME

  MAX_JOBS_FOR_EACH_NODE = 10

  def self.perform
    Host.all.each do |host|
      num = MAX_JOBS_FOR_EACH_NODE - host.submitted_runs.count
      num = 0 if num < 0
      runs = host.submittable_runs.limit(num)
      host.submit(runs)
    end

    # enqueue a job for 5 minutes later
  end
end
