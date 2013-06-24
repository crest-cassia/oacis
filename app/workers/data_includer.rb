class DataIncluder

  QUEUE_NAME = :data_includer_queue
  @queue = QUEUE_NAME

  INPUT_JSON_FILENAME = '_input.json'
  OUTPUT_JSON_FILENAME = '_output.json'
  FILES_TO_SKIP_COPY = [INPUT_JSON_FILENAME, OUTPUT_JSON_FILENAME]

  def self.perform(run_info)
    run = Run.find( run_info["run_id"] )
    work_dir = run_info["work_dir"] ? Pathname.new(run_info["work_dir"]) : nil
    host = run_info["host_id"] ? Host.find(run_info["host_id"]) : nil
    run_status = run_info["run_status"]

    stat = run_status["status"].to_sym
    if stat == :finished or stat == :failed
      copy_files(work_dir, run.dir, host)
      run_status["included_at"] = DateTime.now
    end

    update_run(run, run_status)

    remove_work_dir(work_dir, host) if stat == :finished

    enqueue_analyzer_jobs(run)
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

  def self.update_run(run, run_status)
    run.hostname = run_status["hostname"] if run_status["hostname"]
    run.cpu_time = run_status["cpu_time"] if run_status["cpu_time"]
    run.real_time = run_status["real_time"] if run_status["real_time"]
    run.started_at = DateTime.parse(run_status["started_at"]) if run_status["started_at"]
    run.finished_at = DateTime.parse(run_status["finished_at"]) if run_status["finished_at"]
    run.included_at = run_status["included_at"] if run_status["included_at"]
    run.status = run_status["status"].to_sym if run_status["status"]
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

  def self.enqueue_analyzer_jobs(run)
    ps = run.parameter_set
    sim = ps.simulator

    if run.status == :finished
      sim.analyzers.where(type: :on_run, auto_run: :yes).each do |azr|
        arn = run.analyses.build(analyzer: azr)
        arn.save and arn.submit
      end

      sim.analyzers.where(type: :on_run, auto_run: :first_run_only).each do |azr|
        scope = ps.runs.where(status: :finished)
        if scope.count == 1 and scope.first.id== run.id
          arn = run.analyses.build(analyzer: azr)
          arn.save and arn.submit
        end
      end
    end

    if run.status == :finished or run.status == :failed
      sim.analyzers.where(type: :on_parameter_set, auto_run: :yes).each do |azr|
        unless ps.runs.nin(status: [:finished, :failed]).exists?
          arn = ps.analyses.build(analyzer: azr)
          arn.save and arn.submit
        end
      end
    end
  end

  def self.on_failure(exception, run_info)
  end
end