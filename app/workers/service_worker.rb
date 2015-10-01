class ServiceWorker < Worker

  INTERVAL = 5

  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "service_worker.pid")
  WORKER_LOG_FILE = Rails.root.join('log', "service_worker.log")
  WORKER_STDOUT_FILE = Rails.root.join('log', "service_worker_out.log")

  TASKS = [
    lambda {|logger| CacheUpdater.perform(logger) }
  ]
end

