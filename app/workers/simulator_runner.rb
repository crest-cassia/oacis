require File.join(File.dirname(__FILE__), 'data_includer')

class SimulatorRunner

  @queue = :simulator_queue

  def self.perform(run_info)
    run_id = run_info["id"]
    command = run_info["command"]
    input = run_info["input"]

    run_status = {}
    work_dir = create_work_dir(run_id)
    Dir.chdir(work_dir) {
      prepare_input(input) if input
      run_status[:hostname] = `hostname`.chomp
      run_status[:started_at] = DateTime.now
      run_status[:status] = :running
      Resque.enqueue(DataIncluder, {run_id: run_id, run_status: run_status}) #set status running
      stat = run_simulator(command)
      run_status.update(stat)
      run_status[:finished_at] = DateTime.now
    }

    arg = {run_id: run_id, work_dir: work_dir.expand_path.to_s, run_status: run_status}
    arg[:host_id] = ENV['CM_HOST_ID'] if ENV['CM_HOST_ID']
    Resque.enqueue(DataIncluder, arg)
  end

  def self.prepare_input(input)
    io = File.open(DataIncluder::INPUT_JSON_FILENAME, 'w')
    io.print input.to_json
    io.close
  end

  def self.create_work_dir(run_id)
    work_dir_base = ENV['CM_WORK_DIR'] || './__work__'
    work_dir_base = Pathname.new(work_dir_base).expand_path
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

  def self.print_warning_messages_on_env
    envs = ['CM_HOST_ID', 'CM_WORK_DIR']
    envs.each do |env|
      unless ENV[env]
        $stderr.puts "WARNING : #{env} is not given"
      end
    end
  end
end

SimulatorRunner.print_warning_messages_on_env