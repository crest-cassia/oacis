class RemoteJobHandler

  class RemoteOperationError < StandardError; end
  class RemoteSchedulerError < StandardError; end
  class RemoteJobError < StandardError; end

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
        error_handle(ex, run, ssh)
      end
    end
  end

  def remote_status(run)
    status = :unknown
    scheduler = SchedulerWrapper.new(@host)
    cmd = scheduler.status_command(run.job_id)
    @host.start_ssh do |ssh|
      begin
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        if rc == 0
          status = scheduler.parse_remote_status(out) if rc == 0
        else
          raise RemoteSchedulerError, "remote_status failed: rc:#{rc}, #{out}, #{err}"
        end
      rescue => ex
        error_handle(ex, run, ssh)
      end
    end
    status
  end

  def cancel_remote_job(run)
    stat = remote_status(run)
    if stat == :submitted or stat == :running
      scheduler = SchedulerWrapper.new(@host)
      cmd = scheduler.cancel_command(run.job_id)
      @host.start_ssh do |ssh|
        begin
          out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
          raise RemoteSchedulerError, "cancel_remote_jos failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
        rescue => ex
          error_handle(ex, run, ssh)
        end
      end
    end
    remove_remote_files(run)
  end

  private
  def create_remote_work_dir(run)
    cmd = "mkdir -p #{RemoteFilePath.work_dir_path(@host,run)}"
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise RemoteOperationError, "\"#{cmd}\" failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
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
        raise RemoteOperationError, "chmod failed : rc:#{rc}, #{out}, #{err}" unless rc == 0
        cmd = "cd #{File.dirname(path)} && ./#{File.basename(path)} #{run.args} 1>> _stdout.txt 2>> _stderr.txt"
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        raise RemoteJobError, "\"#{cmd}\" failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
      end
    end
  end

  def prepare_job_script(run)
    jspath = RemoteFilePath.job_script_path(@host, run)
    @host.start_ssh do |ssh|
      SSHUtil.write_remote_file(ssh, jspath, run.job_script)
      out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{jspath}")
      raise RemoteOperationError, "chmod failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
    end
    jspath
  end

  def submit_to_scheduler(run, job_script_path)
    job_parameters = run.host_parameters || {}
    job_parameters["mpi_procs"] = run.mpi_procs
    job_parameters["omp_threads"] = run.omp_threads
    wrapper = SchedulerWrapper.new(@host)
    cmd = wrapper.submit_command(job_script_path, run.id.to_s, job_parameters)
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise RemoteSchedulerError, "#{cmd} failed: rc:#{rc}, #{err}" unless rc == 0
      run.status = :submitted

      job_id = wrapper.parse_jobid_from_submit_command(out)
      run.job_id = job_id
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

  def error_handle(exception, run, ssh)
    if exception.is_a?(RemoteOperationError)
      run.update_attribute(:error_messages, "RemoteOperaion is failed.\n#{exception.inspect}\n#{exception.backtrace}")
      #retry the operation in next time
      raise exception # this error is catched by job_observer
    elsif exception.is_a?(RemoteJobError)
      work_dir = RemoteFilePath.work_dir_path(@host, run)
      SSHUtil.download_recursive(ssh, work_dir, run.dir) if SSHUtil.exist?(ssh, work_dir)
      remove_remote_files(run) # try it once even when remove operation is failed.
      run.update_attribute(:status, :failed)
      run.update_attribute(:error_messages, "#{exception.inspect}\n#{exception.backtrace}")
    elsif exception.is_a?(RemoteSchedulerError)
      run.update_attribute(:error_messages, "Xsub is failed. \n#{exception.inspect}\n#{exception.backtrace}")
      run.update_attribute(:status, :failed)
      raise exception # this error is catched by job_observer
    else
      if exception.inspect.to_s =~ /#<NoMethodError: undefined method `stat' for nil:NilClass>/
        run.update_attribute(:error_messages, "failed to establish ssh connection to host(#{run.submitted_to.name})\n#{exception.inspect}\n#{exception.backtrace}")
      else
        run.update_attribute(:error_messages, "#{exception.inspect}\n#{exception.backtrace}")
      end
      raise exception # this error is catched by job_observer
    end
  end
end
