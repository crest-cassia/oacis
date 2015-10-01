if $0 == __FILE__
  JobObserverWorker.spawn!(log_file: JobObserverWorker::WORKER_STDOUT_FILE,
                   pid_file: JobObserverWorker::WORKER_PID_FILE,
                   sync_log: true,
                   working_dir: Rails.root,
                   singleton: true,
                   timeout: 30
                   )
end

