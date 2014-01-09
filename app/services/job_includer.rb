module JobIncluder

  def self.include_manual_job(archive_path, run)
    FileUtils.mv( archive_path, run.dir.join('..') )
    include_archive(run)
    create_auto_run_analyzers(run)
    run.delete_files_for_manual_submission
  end

  def self.include_remote_job(host, run)
    host.start_ssh {|ssh|
      if remote_file_is_ready_to_include(host, run, ssh)
        download_remote_file(host, run, ssh)
        include_archive(run)
      else
        download_work_dir_if_exists(host, run, ssh)
        run.status = :failed
        run.save!
      end

      remove_remote_files( ssh, remote_path.all_file_paths(run) )
      create_auto_run_analyzers
    }
  end

  private
  def self.include_archive(run)
    JobScriptUtil.expand_result_file_and_update_run(run)
  end

  def self.create_auto_run_analyzers(run)
    run.enqueue_auto_run_analyzers
  end

  def self.remote_file_is_ready_to_include(host, run, ssh)
    remote_path = RemoteFilePath.new(host)
    archive = remote_path.result_file_path(run)
    work_dir = remote_path.work_dir_path(run)

    SSHUtil.exist?(ssh, archive) and !(SSHUtil.exist?(ssh, work_dir))
  end

  def self.download_remote_file(host, run, ssh)
    archive = RemoteFilePath.new(host).result_file_path(run)
    base = File.basename(archive)
    SSHUtil.download(ssh, archive, run.dir.join('..', base))
  end

  def self.download_work_dir_if_exists(host, run, ssh)
    work_dir = RemoteFilePath.new(host).work_dir_path(run)
    if SSHUtil.exist?(work_dir)
      SSHUtil.download_recursive(ssh, work_dir, run.dir)
    end
  end

  def self.remove_remote_files(ssh, paths)
    paths.each do |path|
      SSHUtil.rm_r(ssh, path) if SSHUtil.exist?(ssh, path)
    end
  end
end
