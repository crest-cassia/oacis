if $0 == __FILE__
  JobWorker.spawn!(log_file: JobWorker::WORKER_STDOUT_FILE,
                   pid_file: JobWorker::WORKER_PID_FILE,
                   sync_log: true,
                   working_dir: Rails.root,
                   singleton: true,
                   timeout: 30
                   )
end

