require File.join(File.dirname(__FILE__),'data_includer')

class SimulatorRunner

  @queue = :simulator_queue

  STATUS_JSON_FILENAME = '_run_status.json'

  def self.perform(run_info)
    run_id = run_info["id"]
    command = run_info["command"]

    work_dir = create_work_dir(run_id)
    Dir.chdir(work_dir) {
      run_status = {}
      run_status[:hostname] = `hostname`.chomp
      run_status[:started_at] = DateTime.now
      stat = run_simulator(command)
      run_status.update(stat)
      run_status[:finished_at] = DateTime.now
      File.open(STATUS_JSON_FILENAME, 'w') do |io|
        io.print JSON.generate(run_status)
      end
    }

    arg = {run_id: run_id, work_dir: work_dir.expand_path.to_s}
    arg[:host_id] = ENV['CM_HOST_ID'] if ENV['CM_HOST_ID']
    Resque.enqueue(DataIncluder, arg)
  end

  def self.create_work_dir(run_id)
    work_dir_base = ENV['CM_WORK_DIR'] || './__work__'
    work_dir_base = Pathname.new(work_dir_base)
    FileUtils.mkdir_p(work_dir_base)
    work_dir = work_dir_base.join(run_id)
    FileUtils.mkdir_p(work_dir)
    return work_dir
  end

  def self.run_simulator(command)
    run_status = {}
    tms = Benchmark.measure {
      system("#{command} 1> _stdout.txt 2> _stderr.txt")
      if $?.to_i == 0
        run_status[:status] = :finished
      else
        run_status[:status] = :failed
      end
      run_status[:rc] = $?.to_i
    }
    run_status[:cpu_time] = tms.cutime
    run_status[:real_time] = tms.real
    return run_status
  end

  def self.on_failure(exception, run_info)
  end
end