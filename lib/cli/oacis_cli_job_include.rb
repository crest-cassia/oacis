class OacisCli < Thor

  desc 'job_include', 'include manually executed jobs'
  method_option :input,
    type:     :array,
    aliases:  '-i',
    desc:     'paths of archived result files',
    required: true
  def job_include
    archives = options[:input]
    archives.size
    archives.each do |archive|
      raise "File #{archive} not found" unless File.exist?(archive)
      run_id = File.basename(archive, '.tar.bz2')
      run = Run.find(run_id)
      unless options[:dry_run]
        FileUtils.mv( archive, run.dir.join('..') )
        JobScriptUtil.expand_result_file_and_update_run(run)
        run.enqueue_auto_run_analyzers
        run.delete_files_for_manual_submission
      end
    end
  end
end
