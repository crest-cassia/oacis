class DataIncluder

  QUEUE_NAME = :data_includer_queue
  @queue = QUEUE_NAME

  STATUS_JSON_FILENAME = '_run_status.json'
  FILES_TO_SKIP_COPY = ['_input.json', '_output.json', '_run_status.json']

  def self.perform(run_info)
    run_id = run_info["run_id"]
    work_dir = Pathname.new(run_info["work_dir"])

    run = Run.find(run_id)
    copy_files(work_dir, run.dir)

    update_run(run, work_dir)

    remove_work_dir(work_dir)
  end

  def self.copy_files(work_dir, run_dir)
    FileUtils.mkdir_p(run_dir)

    Dir.chdir(work_dir) {
      Dir.glob('*').each do |file|
        next if FILES_TO_SKIP_COPY.include?(file)
        FileUtils.cp_r(file, run_dir)
      end
    }
  end

  def self.update_run(run, work_dir)
    json_path = work_dir.join(STATUS_JSON_FILENAME)
    status_hash = JSON.load(File.open(json_path))
    run.hostname = status_hash["hostname"]
    run.cpu_time = status_hash["cpu_time"]
    run.real_time = status_hash["real_time"]
    run.started_at = DateTime.parse(status_hash["started_at"])
    run.finished_at = DateTime.parse(status_hash["finished_at"])
    run.included_at = DateTime.now
    run.status = status_hash["status"].to_sym
    run.save!
  end

  def self.remove_work_dir(work_dir)
    FileUtils.rm_r(work_dir)
  end

  def self.on_failure(exception, run_info)
  end
end