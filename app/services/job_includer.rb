module JobIncluder

  def self.include_manual_job(archive_path, submittable)
    FileUtils.mv( archive_path, submittable.dir.join('..') )
    include_archive(submittable)
    create_auto_run_analyses(submittable)
    submittable.send(:delete_files_for_manual_submission)
  end

  def self.include_remote_job(host, submittable)
    host.start_ssh {|ssh|
      if remote_file_is_ready_to_include(host, submittable, ssh)
        if host.mounted_work_base_dir.present?
          move_local_file(host, submittable)
          include_work_dir(submittable)
        else
          download_remote_file(host, submittable, ssh)
          include_archive(submittable)
        end
      else
        submittable.status = :failed
        submittable.save!
        download_work_dir_if_exists(host, submittable, ssh)
        include_work_dir(submittable)
      end

      remove_remote_files( ssh, RemoteFilePath.all_file_paths(host, submittable) )
      create_auto_run_analyses(submittable)
    }
  end

  private
  def self.include_archive(submittable)
    JobScriptUtil.expand_result_file(submittable)
    JobScriptUtil.update_run(submittable)
  end

  def self.include_work_dir(submittable)
    JobScriptUtil.update_run(submittable)
  end

  def self.create_auto_run_analyses(submittable)
    return if submittable.is_a?(Analysis)
    run = submittable
    runs = run.parameter_set.runs
    analyzers = run.simulator.analyzers

    if run.status == :finished
      analyzers.where(type: :on_run, auto_run: :yes).each do |azr|
        create_auto_analysis(run, azr)
      end

      analyzers.where(type: :on_run, auto_run: :first_run_only).each do |azr|
        unless runs.where(status: :finished).ne(id: run.id).exists?
          create_auto_analysis(run, azr)
        end
      end
    end

    if run.status == :finished or run.status == :failed
      analyzers.where(type: :on_parameter_set, auto_run: :yes).each do |azr|
        unless runs.nin(status: [:finished, :failed]).exists?
          create_auto_analysis(run.parameter_set, azr)
        end
      end
    end
  end

  def self.create_auto_analysis(analyzable, analyzer)
    host = analyzer.auto_run_submitted_to
    anl = analyzable.analyses.build(analyzer: analyzer, submitted_to: host)
    if host
      host_param = {}
      host.host_parameter_definitions.each {|hpd| host_param[hpd.key] = hpd.default }
      anl.host_parameters = host_param
      anl.mpi_procs = host.min_mpi_procs if analyzer.support_mpi
      anl.omp_threads = host.min_omp_threads if analyzer.support_omp
    end
    anl.save!
    anl
  end

  def self.remote_file_is_ready_to_include(host, submittable, ssh)
    archive = RemoteFilePath.result_file_path(host, submittable)
    return SSHUtil.exist?(ssh, archive)
  end

  def self.download_remote_file(host, submittable, ssh)
    archive = RemoteFilePath.result_file_path(host, submittable)
    base = File.basename(archive)
    SSHUtil.download(ssh, archive, submittable.dir.join('..', base))

    download_scheduler_logs(host, submittable, ssh)
  end

  def self.move_local_file(host, submittable)
    work_dir = map_remote_path_to_mounted_path(host, RemoteFilePath.work_dir_path(host, submittable))
    archive = map_remote_path_to_mounted_path(host, RemoteFilePath.result_file_path(host, submittable))
    cmd = "rsync -a #{work_dir}/ #{submittable.dir} && mv #{archive} #{submittable.dir.join("..")}/"
    system(cmd)
    raise "can not move work_directory from #{work_dir}" unless $?.exitstatus == 0

    RemoteFilePath.scheduler_log_file_paths(host, submittable).each do |path|
      if path.exist?
        FileUtils.mv(map_remote_path_to_mounted_path(host, path), submittable.dir)
      end
    end
  end

  def self.map_remote_path_to_mounted_path(host, remote_path)
    relative_path = remote_path.relative_path_from(Pathname.new(host.work_base_dir))
    Pathname.new(host.mounted_work_base_dir).join(relative_path)
  end

  def self.download_work_dir_if_exists(host, submittable, ssh)
    work_dir = RemoteFilePath.work_dir_path(host, submittable)
    if SSHUtil.exist?(ssh, work_dir)
      SSHUtil.download_recursive(ssh, work_dir, submittable.dir)
    end
    download_scheduler_logs(host, submittable, ssh)
  end

  def self.download_scheduler_logs(host, submittable, ssh)
    #include scheduler logs
    logs = RemoteFilePath.scheduler_log_file_paths(host, submittable)
    logs.each do |path|
      SSHUtil.download_recursive_if_exist(ssh, path, submittable.dir.join(path.basename))
    end
  end

  def self.remove_remote_files(ssh, paths)
    SSHUtil.rm_r(ssh,paths)
  end
end
