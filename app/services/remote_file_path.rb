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

  def self.scheduler_log_file_paths(host, run)
    a = []
    case host.scheduler_type
    when "PJM"
      a << Pathname.new("~").join("#{run.id}.sh.o#{run.job_id}")
      a << Pathname.new("~").join("#{run.id}.sh.e#{run.job_id}")
      a << Pathname.new("~").join("#{run.id}.sh.i#{run.job_id}")
    when "PJM_k"
      a << Pathname.new("~").join("J#{run.id}.sh.o#{run.job_id}")
      a << Pathname.new("~").join("J#{run.id}.sh.e#{run.job_id}")
      a << Pathname.new("~").join("J#{run.id}.sh.i#{run.job_id}")
      a << Pathname.new("~").join("J#{run.id}.sh.s#{run.job_id}")
    when "torque"
      a << Pathname.new("~").join("#{run.id}.sh.o#{run.job_id.to_i}") # run.job_id = 12345.host
      a << Pathname.new("~").join("#{run.id}.sh.e#{run.job_id.to_i}")
    end
    a
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
