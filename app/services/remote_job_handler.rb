class RemoteJobHandler

  class LocalPreprocessError < StandardError; end
  class RemoteOperationError < StandardError; end
  class RemoteSchedulerError < StandardError; end
  class RemoteJobError < StandardError; end

  def initialize(host)
    @host = host
  end

  def submit_remote_job(job)
    @host.start_ssh do |ssh|
      begin
        set_submitted_to_if_necessary(job)
        execute_local_pre_process(job)
        create_remote_work_dir(job)
        prepare_input_json(job)
        prepare_input_files_for_analysis(job) if job.is_a?(Analysis)
        copy_results_of_local_pre_process(job)
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
        out = SSHUtil.execute(ssh, cmd)
        raise RemoteSchedulerError if out.empty?
        status = scheduler.parse_remote_status(out)
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
          out = SSHUtil.execute(ssh, cmd)
          raise RemoteSchedulerError, "cancel_remote_job failed: #{out}" unless out.chomp[-1] == '0'
        rescue => ex
          error_handle(ex, job, ssh)
        end
      end
    end
    remove_remote_files(job)
  end

  private
  def set_submitted_to_if_necessary(job)
    if job.submitted_to.nil?
      job.submitted_to = @host
      job.host_parameters = @host.default_host_parameters
      job.save!
    end
  end

  def execute_local_pre_process(job)
    return unless job.executable.local_pre_process_script.present?
    Dir.chdir( job.dir ) {
      if input = job.input
        File.open('_input.json', 'w') {|io|
          io.print input.to_json
          io.flush
        }
      end
      # prepare _input dir
      if job.is_a?(Analysis)
        FileUtils.mkdir_p('_input')
        Dir.chdir('_input') do
          job.input_files.each do |o,d|
            FileUtils.ln_s(o, d)
          end
        end
      end

      script = job.executable.local_pre_process_script
      File.open('_lpreprocess.sh', 'w') {|io|
        io.puts script; io.flush
      }
      FileUtils.chmod(0755, '_lpreprocess.sh')
      cmd = "./_lpreprocess.sh #{job.args} 1>> _stdout.txt 2>> _stderr.txt"
      system(cmd)
      raise LocalPreprocessError unless $?.to_i == 0

      clean_up_local_preprocess_files
    }
  end

  def clean_up_local_preprocess_files
    entries = ['_lpreprocess.sh', '_input.json', '_input'].select {|e| File.exist?(e) }
    FileUtils.rm_rf(entries)
  end

  def create_remote_work_dir(job)
    cmd = "mkdir -p #{RemoteFilePath.work_dir_path(@host,job)}; echo $?"
    @host.start_ssh do |ssh|
      out = SSHUtil.execute(ssh, cmd)
      raise RemoteOperationError, "\"#{cmd}\" failed: #{out}" unless out.chomp[-1]=='0'
    end
  end

  def remote_path_to_mounted_local_path(path)
    relative_path = path.relative_path_from(Pathname.new(@host.work_base_dir))
    Pathname.new(@host.mounted_work_base_dir).join(relative_path).expand_path
  end

  def prepare_input_json(job)
    input = job.input
    if input
      rpath = RemoteFilePath.input_json_path(@host,job)
      if @host.mounted_work_base_dir.present?
        mounted_path = remote_path_to_mounted_local_path(rpath)
        File.open(mounted_path, 'w') do |f|
          f.print(input.to_json)
          f.flush
        end
      else
        SSHUtil.write_remote_file(@host.name, rpath, input.to_json)
      end
    end
  end

  def prepare_input_files_for_analysis(job)
    org_dest_list = job.input_files.map do |origin,dest|
      [origin, Pathname('_input').join(dest)]
    end
    if @host.mounted_work_base_dir.present?
      copy_files_to_work_dir_via_copy(job, org_dest_list)
    else
      copy_files_to_work_dir_via_ssh(job, org_dest_list)
    end
  end

  def copy_results_of_local_pre_process(job)
    return unless job.executable.local_pre_process_script.present?
    org_dest_list = filelist_of_local_preprocess(job)
    if @host.mounted_work_base_dir.present?
      copy_files_to_work_dir_via_copy(job, org_dest_list)
    else
      copy_files_to_work_dir_via_ssh(job, org_dest_list)
    end
  end

  def filelist_of_local_preprocess(job)
    org_dest_list = []
    Dir.chdir(job.dir) {
      org_dest_list = Dir.glob("**/*").map {|f| [ Pathname.new(f).expand_path, f ] }
    }
    org_dest_list
  end

  def copy_files_to_work_dir_via_copy(job, org_dest_list)
    remote_path = RemoteFilePath.work_dir_path(@host,job)
    mounted_work_dir = remote_path_to_mounted_local_path(remote_path)

    relative_subdirs = org_dest_list.map {|o,d| File.dirname(d) }.uniq.select {|d| d != "."}
    subdirs = relative_subdirs.map {|d| mounted_work_dir.join(d) }
    FileUtils.mkdir_p(subdirs) unless subdirs.empty?
    org_dest_list.each do |origin,dest|
      FileUtils.cp_r(origin, mounted_work_dir.join(dest) )
    end
  end

  def copy_files_to_work_dir_via_ssh(job, org_dest_list)
    remote_work_dir = RemoteFilePath.work_dir_path(@host,job)

    relative_subdirs = org_dest_list.map {|o,d| File.dirname(d) }.uniq.select {|d| d != "."}
    subdirs = relative_subdirs.map {|d| remote_work_dir.join(d) }
    cmd = "mkdir -p #{subdirs.join(' ')}"

    @host.start_ssh do |ssh|
      SSHUtil.execute(ssh, cmd)
      org_dest_list.each do |origin,dest|
        remote_path = remote_work_dir.join( dest )
        SSHUtil.upload(@host.name, origin, remote_path)
      end
    end
  end

  def execute_pre_process(job)
    script = job.executable.pre_process_script
    if script.present?
      path = RemoteFilePath.pre_process_script_path(@host, job)
      @host.start_ssh do |ssh|
        SSHUtil.write_remote_file(@host.name, path, script)
        out = SSHUtil.execute(ssh, "chmod +x #{path}; echo $?")
        raise RemoteOperationError, "chmod failed : #{out}" unless out.chomp[-1]=='0'
        cmd = "cd #{File.dirname(path)} && ./#{File.basename(path)} #{job.args} 1>> _stdout.txt 2>> _stderr.txt"
        out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
        raise RemoteJobError, "\"#{cmd}\" failed: rc:#{rc}, #{out}, #{err}" unless rc == 0
      end
    end
  end

  def prepare_job_script(job)
    jspath = RemoteFilePath.job_script_path(@host, job)

    if @host.mounted_work_base_dir.present?
      mounted_path = remote_path_to_mounted_local_path(jspath)
      File.open(mounted_path, 'w') do |f|
        f.print(job.job_script)
        f.flush
      end
    else
      SSHUtil.write_remote_file(@host.name, jspath, job.job_script)
    end

    @host.start_ssh do |ssh|
      out = SSHUtil.execute(ssh, "chmod +x #{jspath}; echo $?")
      raise RemoteOperationError, "chmod failed: #{out}" unless out.chomp[-1] == '0'
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
      StatusChannel.broadcast_to('message', OacisChannelUtil.createStatusMessage(job));
    end
  end

  def remove_remote_files(job)
    @host.start_ssh do |ssh|
      paths = RemoteFilePath.all_file_paths(@host, job)
      SSHUtil.rm_r(ssh, paths)
    end
  end

  def error_handle(exception, job, ssh)
    if exception.is_a?(RemoteOperationError)
      job.update_attribute(:error_messages, "RemoteOperaion is failed.\n#{exception.inspect}\n#{exception.backtrace}")
      #retry the operation in next time
      # this error is caught by job_submitter or job_observer
      raise exception
    elsif exception.is_a?(RemoteJobError)
      work_dir = RemoteFilePath.work_dir_path(@host, job)
      SSHUtil.download_directory(@host.name, work_dir, job.dir) if SSHUtil.exist?(ssh, work_dir)
      remove_remote_files(job) # try it once even when remove operation is failed.
      job.update_attribute(:status, :failed)
      job.update_attribute(:error_messages, "#{exception.inspect}\n#{exception.backtrace}")
    elsif exception.is_a?(RemoteSchedulerError)
      job.update_attribute(:error_messages, "Xsub is failed. \n#{exception.inspect}\n#{exception.backtrace}")
      job.update_attribute(:status, :failed)
      raise exception # this error is catched by job_observer
    elsif exception.is_a?(LocalPreprocessError)
      job.update_attribute(:error_messages, "failed to execute local preprocess.\n#{exception.inspect}\n#{exception.backtrace})")
      job.update_attribute(:status, :failed)
      raise exception
    else
      if exception.inspect.to_s =~ /#<NoMethodError: undefined method `stat' for nil:NilClass>/
        job.update_attribute(:error_messages, "failed to establish ssh connection to host(#{job.submitted_to.name})\n#{exception.inspect}\n#{exception.backtrace}")
      else
        job.update_attribute(:error_messages, "#{exception.inspect}\n#{exception.backtrace}")
      end
      # this error is caught by job_submitter or job_observer
      raise exception
    end
  end
end
