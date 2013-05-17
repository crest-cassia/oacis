class DataIncluder

  QUEUE_NAME = :data_includer_queue
  @queue = QUEUE_NAME

  STATUS_JSON_FILENAME = '_run_status.json'
  OUTPUT_JSON_FILENAME = '_output.json'
  FILES_TO_SKIP_COPY = ['_input.json', OUTPUT_JSON_FILENAME, STATUS_JSON_FILENAME]

  def self.perform(run_info)
    run_id = run_info["run_id"]
    work_dir = Pathname.new(run_info["work_dir"])
    host_id = run_info["host_id"]

    run = Run.find(run_id)
    host = Host.find(host_id)
    copy_files(work_dir, run.dir, host)

    update_run(run)

    remove_work_dir(work_dir, host)
  end

  def self.copy_files(work_dir, run_dir, host = nil)
    FileUtils.mkdir_p(run_dir)

    if host
      host.download(work_dir, run_dir)
    else
      Dir.chdir(work_dir) {
        Dir.glob('*').each do |file|
          FileUtils.cp_r(file, run_dir)
        end
      }
    end
  end

  def self.update_run(run)
    json_path = run.dir.join(STATUS_JSON_FILENAME)
    status_hash = JSON.load(File.open(json_path))
    run.hostname = status_hash["hostname"]
    run.cpu_time = status_hash["cpu_time"]
    run.real_time = status_hash["real_time"]
    run.started_at = DateTime.parse(status_hash["started_at"])
    run.finished_at = DateTime.parse(status_hash["finished_at"])
    run.included_at = DateTime.now
    run.status = status_hash["status"].to_sym
    run.save!

    json_path = run.dir.join(OUTPUT_JSON_FILENAME)
    if File.exist?(json_path)
      result = JSON.load(File.open(json_path))
      run.result = result
      run.save!
    end

    # remove json files
    FILES_TO_SKIP_COPY.each do |file|
      file_to_remove = run.dir.join(file)
      FileUtils.rm(file_to_remove) if File.exist?(file_to_remove)
    end
  end

  def self.remove_work_dir(work_dir, host = nil)
    if host
      host.rm_r(work_dir)
    else
      FileUtils.rm_r(work_dir)
    end
  end

  def self.on_failure(exception, run_info)
  end
end