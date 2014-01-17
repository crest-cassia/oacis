class RemoteJobHandler

  def initialize(host)
    @host = host
  end

  def submit_remote_job(run)
    @host.start_ssh do |ssh|
      begin
        create_remote_work_dir(run)
        prepare_input_json(run)
        execute_pre_process(run)
        job_script_path = prepare_job_script(run)
        submit_to_scheduler(run, job_script_path)
      rescue => ex
        work_dir = RemoteFilePath.work_dir_path(@host, run)
        SSHUtil.download_recursive(ssh, work_dir, run.dir) if SSHUtil.exist?(ssh, work_dir)
        remove_remote_files(run)
        run.update_attribute(:status, :failed)
        raise ex
      end
    end
  end

  def remote_status(run)
    status = :unknown
    scheduler = SchedulerWrapper.new(@host.scheduler_type)
    cmd = scheduler.status_command(run.job_id)
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      status = scheduler.parse_remote_status(out) if rc == 0
    end
    status
  end

  def cancel_remote_job(run)
    stat = remote_status(run)
    if stat == :submitted or stat == :running
      scheduler = SchedulerWrapper.new(@host.scheduler_type)
      cmd = scheduler.cancel_command(run.job_id)
      @host.start_ssh do |ssh|
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        $stderr.puts out, err, rc unless rc == 0
      end
      remove_remote_files(run)
    end
  end

  private
  def create_remote_work_dir(run)
    cmd = "mkdir -p #{RemoteFilePath.work_dir_path(@host,run)}"
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise "\"#{cmd}\" failed: #{rc}, #{out}, #{err}" unless rc == 0
    end
  end

  def prepare_input_json(run)
    input = run.input
    if input
      @host.start_ssh do |ssh|
        SSHUtil.write_remote_file(ssh, RemoteFilePath.input_json_path(@host,run), input.to_json)
      end
    end
  end

  def execute_pre_process(run)
    script = run.simulator.pre_process_script
    if script.present?
      path = RemoteFilePath.pre_process_script_path(@host, run)
      @host.start_ssh do |ssh|
        SSHUtil.write_remote_file(ssh, path, script)
        out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{path}")
        raise "chmod failed : #{rc}, #{out}, #{err}" unless rc == 0
        cmd = "cd #{File.dirname(path)} && ./#{File.basename(path)} #{run.args} 1>> _stdout.txt 2>> _stderr.txt"
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        raise "\"#{cmd}\" failed: #{rc}, #{out}, #{err}" unless rc == 0
      end
    end
  end

  def prepare_job_script(run)
    jspath = RemoteFilePath.job_script_path(@host, run)
    @host.start_ssh do |ssh|
      SSHUtil.write_remote_file(ssh, jspath, run.job_script)
      out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{jspath}")
      raise "chmod failed : #{rc}, #{out}, #{err}" unless rc == 0
    end
    jspath
  end

  def submit_to_scheduler(run, job_script_path)
    cmd = SchedulerWrapper.new(@host.scheduler_type).submit_command(job_script_path)
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise "#{cmd} failed : #{rc}, #{err}" unless rc == 0
      run.status = :submitted
      run.job_id = out.chomp
      run.submitted_at = DateTime.now
      run.save!
    end
  end

  def remove_remote_files(run)
    @host.start_ssh do |ssh|
      RemoteFilePath.all_file_paths(@host, run).each do |path|
        SSHUtil.rm_r(ssh, path) if SSHUtil.exist?(ssh, path)
      end
    end
  end
end
