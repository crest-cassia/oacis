class JobObserverWorker < Worker

  INTERVAL = 5

  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "job_observer_worker.pid")
  WORKER_LOG_FILE = Rails.root.join('log', "job_observer_worker.log")
  WORKER_STDOUT_FILE = Rails.root.join('log', "job_observer_worker_out.log")

  TASKS = [
    lambda {|logger| JobObserver.perform(logger) }
  ]
end

