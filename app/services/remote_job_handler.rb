class RemoteJobHandler

  class RemoteOperationError < StandardError; end
  class RemoteSchedulerError < StandardError; end
  class RemoteJobError < StandardError; end

  def initialize(host)
    @host = host
  end

  def submit_remote_job(job)
    @host.start_ssh do |ssh|
      begin
        create_remote_work_dir(job)
        prepare_input_json(job)
        execute_pre_process(job)
        job_script_path = prepare_job_script(job)
        submit_to_scheduler(job, job_script_path)
      rescue => ex
        error_handle(ex, job, ssh)
      end
    end
  end

  def remote_status(job)
    status = :unknown
    scheduler = SchedulerWrapper.new(@host)
    cmd = scheduler.status_command(job.job_id)
    @host.start_ssh do |ssh|
      begin
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        if rc == 0
          status = scheduler.parse_remote_status(out) if rc == 0
        else
          raise RemoteSchedulerError, "remote_status failed: rc:#{rc}, #{out}, #{err}"
        end
      rescue => ex
        error_handle(ex, job, ssh)
      end
    end
    status
  end

  def cancel_remote_job(job)
    stat = remote_status(job)
    if stat == :submitted or stat == :running
      scheduler = SchedulerWrapper.new(@host)
      cmd = scheduler.cancel_command(job.job_id)
      @host.start_ssh do |ssh|
        begin
          out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
          raise RemoteSchedulerError, "cancel_remote_jos failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
        rescue => ex
          error_handle(ex, job, ssh)
        end
      end
    end
    remove_remote_files(job)
  end

  private
  def create_remote_work_dir(job)
    cmd = "mkdir -p #{RemoteFilePath.work_dir_path(@host,job)}"
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise RemoteOperationError, "\"#{cmd}\" failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
    end
  end

  def prepare_input_json(job)
    input = job.input
    if input
      @host.start_ssh do |ssh|
        SSHUtil.write_remote_file(ssh, RemoteFilePath.input_json_path(@host,job), input.to_json)
      end
    end
  end

  def execute_pre_process(job)
    script = job.executable.pre_process_script
    if script.present?
      path = RemoteFilePath.pre_process_script_path(@host, job)
      @host.start_ssh do |ssh|
        SSHUtil.write_remote_file(ssh, path, script)
        out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{path}")
        raise RemoteOperationError, "chmod failed : rc:#{rc}, #{out}, #{err}" unless rc == 0
        cmd = "cd #{File.dirname(path)} && ./#{File.basename(path)} #{job.args} 1>> _stdout.txt 2>> _stderr.txt"
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        raise RemoteJobError, "\"#{cmd}\" failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
      end
    end
  end

  def prepare_job_script(job)
    jspath = RemoteFilePath.job_script_path(@host, job)
    @host.start_ssh do |ssh|
      SSHUtil.write_remote_file(ssh, jspath, job.job_script)
      out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{jspath}")
      raise RemoteOperationError, "chmod failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
    end
    jspath
  end

  def submit_to_scheduler(job, job_script_path)
    job_parameters = job.host_parameters || {}
    job_parameters["mpi_procs"] = job.mpi_procs
    job_parameters["omp_threads"] = job.omp_threads
    wrapper = SchedulerWrapper.new(@host)
    cmd = wrapper.submit_command(job_script_path, job.id.to_s, job_parameters)
    @host.start_ssh do |ssh|
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise RemoteSchedulerError, "#{cmd} failed: rc:#{rc}, #{err}" unless rc == 0
      job.status = :submitted

      job_id = wrapper.parse_jobid_from_submit_command(out)
      job.job_id = job_id
      job.submitted_at = DateTime.now
      job.save!
    end
  end

  def remove_remote_files(job)
    @host.start_ssh do |ssh|
      RemoteFilePath.all_file_paths(@host, job).each do |path|
        SSHUtil.rm_r(ssh, path) if SSHUtil.exist?(ssh, path)
      end
    end
  end

  def error_handle(exception, job, ssh)
    if exception.is_a?(RemoteOperationError)
      job.update_attribute(:error_messages, "RemoteOperaion is failed.\n#{exception.inspect}\n#{exception.backtrace}")
      #retry the operation in next time
      raise exception # this error is catched by job_observer
    elsif exception.is_a?(RemoteJobError)
      work_dir = RemoteFilePath.work_dir_path(@host, job)
      SSHUtil.download_recursive(ssh, work_dir, job.dir) if SSHUtil.exist?(ssh, work_dir)
      remove_remote_files(job) # try it once even when remove operation is failed.
      job.update_attribute(:status, :failed)
      job.update_attribute(:error_messages, "#{exception.inspect}\n#{exception.backtrace}")
    elsif exception.is_a?(RemoteSchedulerError)
      job.update_attribute(:error_messages, "Xsub is failed. \n#{exception.inspect}\n#{exception.backtrace}")
      job.update_attribute(:status, :failed)
      raise exception # this error is catched by job_observer
    else
      if exception.inspect.to_s =~ /#<NoMethodError: undefined method `stat' for nil:NilClass>/
        job.update_attribute(:error_messages, "failed to establish ssh connection to host(#{job.submitted_to.name})\n#{exception.inspect}\n#{exception.backtrace}")
      else
        job.update_attribute(:error_messages, "#{exception.inspect}\n#{exception.backtrace}")
      end
      raise exception # this error is catched by job_observer
    end
  end
end
