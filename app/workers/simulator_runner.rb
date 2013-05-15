class SimulatorRunner

  @queue = :simulator_queue

  STATUS_JSON_FILENAME = '_run_status.json'

  def self.perform(run_info)
    run_id = run_info["id"]
    command = run_info["command"]
    run_dir = run_info["dir"]

    FileUtils.mkdir_p(run_dir) if FileTest.directory?(run_dir)
    Dir.chdir(run_dir) {
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
    # TODO: enqueue DataIncluder
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