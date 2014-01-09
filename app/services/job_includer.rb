module JobIncluder

  def self.include_remote_jobs
  end

  def self.include_manual_jobs(archive_path, run)
    FileUtils.mv( archive_path, run.dir.join('..') )
    include_archive(run)
    create_auto_run_analyzers(run)
    run.delete_files_for_manual_submission
  end

  private
  def self.include_archive(run)
    JobScriptUtil.expand_result_file_and_update_run(run)
  end

  def self.create_auto_run_analyzers(run)
    run.enqueue_auto_run_analyzers
  end
end
