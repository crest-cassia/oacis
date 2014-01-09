class OacisCli < Thor

  desc 'job_include', 'include manually executed jobs'
  method_option :input,
    type:     :array,
    aliases:  '-i',
    desc:     'paths of archived result files',
    required: true
  def job_include
    archives = options[:input]
    archives.each do |archive|
      run = find_included_run(archive)
      next if options[:dry_run]
      JobIncluder.include_manual_job(archive, run)
    end
  end

  private
  def find_included_run(archive)
    run_id = File.basename(archive, '.tar.bz2')
    run = Run.find(run_id)
    if [:finished, :failed, :cancelled].include?(run.status)
      raise "status of run #{run_id} is not valid"
    end
    run
  end
end
