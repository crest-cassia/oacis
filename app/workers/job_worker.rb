class JobWorker < Worker

  INTERVAL = 5

  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "job_worker_#{Rails.env}.pid")
  WORKER_LOG_FILE = Rails.root.join('log', "job_worker_#{Rails.env}.log")
  WORKER_STDOUT_FILE = Rails.root.join('log', "job_worker_#{Rails.env}_out.log")

  TASKS = [
    lambda {|logger| JobSubmitter.perform(logger) },
    lambda {|logger| JobObserver.perform(logger) }
  ]
end

