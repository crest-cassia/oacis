class JobSubmitterWorker < Worker

  INTERVAL = 5

  WORKER_ID = :submitter
  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "job_submitter_worker.pid")
  WORKER_LOG_FILE = Rails.root.join('log', "job_submitter_worker.log")
  WORKER_STDOUT_FILE = Rails.root.join('log', "job_submitter_worker_out.log")

  TASKS = [
    lambda {|logger| JobSubmitter.perform(logger) }
  ]
end

