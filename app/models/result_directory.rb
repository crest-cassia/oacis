module ResultDirectory

  DefaultResultRoot = Rails.root.join('Result')

  def self.set_root(root_dir)
    @@root_dir = root_dir
  end

  def self.root
    @@root_dir ||= DefaultResultRoot
    return @@root_dir
  end

  def self.simulator_path(simulator)
    root.join(simulator.to_param)
  end

  def self.parameter_path(parameter)
    prm = Parameter.find(parameter)
    simulator_path(prm.simulator_id).join(prm.to_param)
  end

  def self.run_path(run)
    run = Run.find(run)
    prm = run.parameter_id
    parameter_path(run.parameter_id).join(run.to_param)
  end

  def self.run_script_path(run)
    run = Run.find(run)
    prm = run.parameter_id
    parameter_path(run.parameter_id).join(run.to_param + '.sh')
  end
end
