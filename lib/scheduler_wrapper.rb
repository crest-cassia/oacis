class SchedulerWrapper

  def initialize(host)
    raise "Not a host : #{host}" unless host.is_a?(Host)
    @work_base_dir = Pathname.new(host.work_base_dir)
  end

  def submit_command(script, run_id, job_parameters = {})
    work_dir = @work_base_dir.join(run_id)
    scheduler_log_dir = @work_base_dir.join(run_id+"_log")
    escaped = Shellwords.escape(job_parameters.to_json)
    "xsub #{script} -d #{work_dir} -l #{scheduler_log_dir} -p #{escaped}"
  end

  def parse_jobid_from_submit_command(output)
    JSON.load(output)["job_id"]
  end

  def all_status_command
    "xstat"
  end

  def status_command(job_id)
    "xstat #{job_id}"
  end

  def parse_remote_status(stdout)
    return :unknown if stdout.empty?
    case JSON.load(stdout)["status"]
    when "queued"
      :submitted
    when "running"
      :running
    when "finished"
      :includable
    else
      raise "unknown status"
    end
  end

  def cancel_command(job_id)
    "xdel #{job_id}"
  end

  def scheduler_log_file_paths(run)
    paths = []
    dir = Pathname.new(@work_base_dir)
    paths << dir.join("#{run.id}_log")
    paths
  end
end
