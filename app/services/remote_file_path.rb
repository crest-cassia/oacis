class RemoteFilePath

  def initialize(host)
    @work_base_dir = host.work_base_dir
  end

  def job_script_path(run)
    Pathname.new(@work_base_dir).join("#{run.id}.sh")
  end

  def pre_process_script_path(run)
    work_dir_path(run).join("_preprocess.sh")
  end

  def input_json_path(run)
    work_dir_path(run).join('_input.json')
  end

  def work_dir_path(run)
    Pathname.new(@work_base_dir).join("#{run.id}")
  end

  def result_file_path(run)
    Pathname.new(@work_base_dir).join("#{run.id}.tar.bz2")
  end

  def all_file_paths(run)
    [
      job_script_path(run),
      input_json_path(run),
      work_dir_path(run),
      result_file_path(run),
      Pathname.new(@work_base_dir).join("#{run.id}_status.json"),
      Pathname.new(@work_base_dir).join("#{run.id}_time.txt"),
      Pathname.new(@work_base_dir).join("#{run.id}.tar")
    ]
  end
end