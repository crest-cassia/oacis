if $0 == __FILE__
  ServiceWorker.spawn!(log_file: ServiceWorker::WORKER_STDOUT_FILE,
                       pid_file: ServiceWorker::WORKER_PID_FILE,
                       sync_log: true,
                       working_dir: Rails.root,
                       singleton: true,
                       timeout: 30
                       )
end

