class WebhookSenderWorker < Worker

    INTERVAL = 60
  
    WORKER_ID = :webhook_sender
    WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "webhook_sender_worker.pid")
    WORKER_LOG_FILE = Rails.root.join('log', "webhook_sender_worker.log")
    WORKER_STDOUT_FILE = Rails.root.join('log', "webhook_sender_worker_out.log")
  
    TASKS = [
      lambda {|logger| WebhookSender.perform(logger) }
    ]
end