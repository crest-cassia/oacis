class SimulatorRunner

  @queue = "simulator_queue_#{Rails.env}".to_sym

  def self.perform(run_id)
    run = Run.find(run_id)
    run_dir = ResultDirectory.run_path(run)
    FileUtils.mkdir_p(run_dir) if FileTest.directory?(run_dir)
    Dir.chdir(run_dir) {
      system("#{run.command} 1> _stdout.txt 2> _stderr.txt")
    }
  end
end