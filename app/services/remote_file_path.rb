module RemoteFilePath

  def self.job_script_path(host, run)
    Pathname.new(host.work_base_dir).join("#{run.id}.sh")
  end

  def self.pre_process_script_path(host, run)
    work_dir_path(host, run).join("_preprocess.sh")
  end

  def self.input_json_path(host, run)
    work_dir_path(host, run).join('_input.json')
  end

  def self.work_dir_path(host, run)
    Pathname.new(host.work_base_dir).join("#{run.id}")
  end

  def self.result_file_path(host, run)
    Pathname.new(host.work_base_dir).join("#{run.id}.tar.bz2")
  end

  def self.all_file_paths(host, run)
    [
      job_script_path(host, run),
      input_json_path(host, run),
      work_dir_path(host, run),
      result_file_path(host, run),
      Pathname.new(host.work_base_dir).join("#{run.id}_status.json"),
      Pathname.new(host.work_base_dir).join("#{run.id}_time.txt"),
      Pathname.new(host.work_base_dir).join("#{run.id}.tar")
    ]
  end
end
