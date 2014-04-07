module JobIncluder

  def self.include_manual_job(archive_path, run)
    FileUtils.mv( archive_path, run.dir.join('..') )
    include_archive(run)
    create_auto_run_analyses(run)
    run.send(:delete_files_for_manual_submission)
  end

  def self.include_remote_job(host, run)
    host.start_ssh {|ssh|
      if remote_file_is_ready_to_include(host, run, ssh)
        download_remote_file(host, run, ssh)
        include_archive(run)
      else
        run.status = :failed
        run.save!
        if host.mounted_work_base_dir.length > 0
          move_local_file(host, run)
        else
          download_work_dir_if_exists(host, run, ssh)
        end
        include_work_dir(run)
      end

      remove_remote_files( ssh, RemoteFilePath.all_file_paths(host, run) )
      create_auto_run_analyses(run)
    }
  end

  private
  def self.include_archive(run)
    JobScriptUtil.expand_result_file(run)
    JobScriptUtil.update_run(run)
  end

  def self.include_work_dir(run)
    JobScriptUtil.update_run(run)
  end

  def self.create_auto_run_analyses(run)
    runs = run.parameter_set.runs
    analyzers = run.simulator.analyzers

    if run.status == :finished
      analyzers.where(type: :on_run, auto_run: :yes).each do |azr|
        run.analyses.create(analyzer: azr)
      end

      analyzers.where(type: :on_run, auto_run: :first_run_only).each do |azr|
        unless runs.where(status: :finished).ne(id: run.id).exists?
          run.analyses.create(analyzer: azr)
        end
      end
    end

    if run.status == :finished or run.status == :failed
      analyzers.where(type: :on_parameter_set, auto_run: :yes).each do |azr|
        unless runs.nin(status: [:finished, :failed]).exists?
          run.parameter_set.analyses.create(analyzer: azr)
        end
      end
    end
  end

  def self.remote_file_is_ready_to_include(host, run, ssh)
    archive = RemoteFilePath.result_file_path(host, run)
    work_dir = RemoteFilePath.work_dir_path(host, run)

    return SSHUtil.exist?(ssh, archive) if host.scheduler_type == "pjm_k"
    SSHUtil.exist?(ssh, archive) and !(SSHUtil.exist?(ssh, work_dir))
  end

  def self.download_remote_file(host, run, ssh)
    archive = RemoteFilePath.result_file_path(host, run)
    base = File.basename(archive)
    SSHUtil.download(ssh, archive, run.dir.join('..', base))

    #include scheduler logs
    logs = RemoteFilePath.scheduler_log_file_paths(host, run)
    logs.each do |path|
      if SSHUtil.exist?(ssh, path)
        SSHUtil.download(ssh, path, run.dir.join(path.basename))
        SSHUtil.rm_r(ssh, path)
      end
    end
  end

  def self.move_local_file(host, run)
    work_dir = Pathname.new(host.mounted_work_base_dir).join(run.id.to_s)
    archive = RemoteFilePath.result_file_path(host, run)
    cmd = "rm -rf #{run.dir}; mv #{work_dir} #{run.dir}; mv #{archive} #{run.dir.join("..")}/"
    system(cmd)
    raise "can not move work_directory from #{work_dir}" unless $?.exitstatus == 0
  end

  def self.download_work_dir_if_exists(host, run, ssh)
    work_dir = RemoteFilePath.work_dir_path(host, run)
    if SSHUtil.exist?(ssh, work_dir)
      SSHUtil.download_recursive(ssh, work_dir, run.dir)
    end

    #include scheduler logs
    logs = RemoteFilePath.scheduler_log_file_paths(host, run)
    logs.each do |path|
      if SSHUtil.exist?(ssh, path)
        SSHUtil.download(ssh, path, run.dir.join(path.basename))
        SSHUtil.rm_r(ssh, path)
      end
    end
  end

  def self.remove_remote_files(ssh, paths)
    paths.each do |path|
      SSHUtil.rm_r(ssh, path) if SSHUtil.exist?(ssh, path)
    end
  end
end
