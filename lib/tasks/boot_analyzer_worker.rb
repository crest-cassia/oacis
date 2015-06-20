if $0 == __FILE__
  AnalyzerWorker.spawn!(log_file:  AnalyzerWorker::WORKER_STDOUT_FILE,
                        pid_file:  AnalyzerWorker::WORKER_PID_FILE,
                        sync_log: true,
                        working_dir: Rails.root,
                        singleton: true,
                        timeout: 30
                        )
end

