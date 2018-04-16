class ResqueWorker < DaemonSpawn::Base

  WORKER_PID_FILE = Rails.root.join('tmp', 'pids', "resque_worker.pid")
  WORKER_STDOUT_FILE = Rails.root.join('log', "resque_worker_out.log")

  def start(args)
    @worker = Resque::Worker.new("#{AcmProto::Application.config.active_job.queue_name_prefix}_default")
    @worker.verbose = true
    @worker.work
  end

  def stop
    @worker.try(:shutdown)
  end

end

if $0 == __FILE__
  ResqueWorker.spawn!(log_file: ResqueWorker::WORKER_STDOUT_FILE,
                   pid_file: ResqueWorker::WORKER_PID_FILE,
                   sync_log: true,
                   working_dir: Rails.root,
                   singleton: true,
                   timeout: 30
                   )
end

