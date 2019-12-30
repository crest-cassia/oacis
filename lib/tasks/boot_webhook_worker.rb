if $0 == __FILE__
  WebhookWorker.spawn!(log_file: WebhookWorker::WORKER_STDOUT_FILE,
                       pid_file: WebhookWorker::WORKER_PID_FILE,
                       sync_log: true,
                       working_dir: Rails.root,
                       singleton: true,
                       timeout: 30
                       )
end

