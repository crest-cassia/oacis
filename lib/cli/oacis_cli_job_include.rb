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
      JobIncluder.include_manual_jobs(archive, options)
    end
  end
end
