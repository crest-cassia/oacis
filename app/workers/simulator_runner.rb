class SimulatorRunner

  @queue = :simulator_queue

  def self.perform(run_id)
    run = Run.find(run_id)
    run_dir = run.dir
    FileUtils.mkdir_p(run_dir) if FileTest.directory?(run_dir)

    elapsed_times = {cpu_time: 0.0, real_time: 0.0}
    Dir.chdir(run_dir) {
      tms = Benchmark.measure {
        system("#{run.command} 1> _stdout.txt 2> _stderr.txt")
      }
      elapsed_times[:cpu_time] = tms.cutime
      elapsed_times[:real_time] = tms.real
    }

    update_runs_table(run, elapsed_times)
  end

  def self.before_perform(run_id)
    run = Run.find(run_id)
    hostname = `hostname`.chomp
    run.set_status_running( {hostname: hostname} )
  end

  def self.update_runs_table(run, atr = {cpu_time: 0.0, real_time: 0.0})
    run.set_status_finished(atr)
  end

end