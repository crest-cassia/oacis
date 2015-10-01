if $0 == __FILE__
  JobSubmitterWorker.spawn!(log_file: JobSubmitterWorker::WORKER_STDOUT_FILE,
                   pid_file: JobSubmitterWorker::WORKER_PID_FILE,
                   sync_log: true,
                   working_dir: Rails.root,
                   singleton: true,
                   timeout: 30
                   )
end

