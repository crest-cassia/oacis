if $0 == __FILE__
  WebhookSenderWorker.spawn!(log_file: WebhookSenderWorker::WORKER_STDOUT_FILE,
                       pid_file: WebhookSenderWorker::WORKER_PID_FILE,
                       sync_log: true,
                       working_dir: Rails.root,
                       singleton: true,
                       timeout: 30
                       )
end

