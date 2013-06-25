class JobSubmitter

  QUEUE_NAME = :job_submitter_queue
  @queue = QUEUE_NAME

  def self.perform(run_info)
  end
end
