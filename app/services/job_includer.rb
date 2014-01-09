module JobIncluder

  def self.include_remote_jobs
  end

  def self.include_manual_jobs(archive_path, options = {dry_run: false})
    run = find_included_run(archive_path)
    return if options[:dry_run]
    FileUtils.mv( archive_path, run.dir.join('..') )
    include_archive(run)
    enqueue_auto_run_analyzers(run)
    run.delete_files_for_manual_submission
  end

  private
  def self.find_included_run(archive)
    run_id = File.basename(archive, '.tar.bz2')
    run = Run.find(run_id)
    if [:finished, :failed, :cancelled].include?(run.status)
      raise "status of run #{run_id} is not valid"
    end
    run
  end

  def self.include_archive(run)
    JobScriptUtil.expand_result_file_and_update_run(run)
  end

  def self.enqueue_auto_run_analyzers(run)
    run.enqueue_auto_run_analyzers
  end
end
