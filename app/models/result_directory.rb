module ResultDirectory

  yml_path = Rails.root.join('config', 'result_directory.yml')
  base_dir = YAML.load(File.open(yml_path))[Rails.env]
  raise "Result directory is not specified for this environment. Edit #{yml_path}"  unless base_dir
  DefaultResultRoot = Rails.root.join('public', base_dir)

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

  def self.parameter_set_path(param_set)
    prm = ParameterSet.find(param_set)
    simulator_path(prm.simulator_id).join(prm.to_param)
  end

  def self.run_path(run)
    run = Run.find(run)
    prm = run.parameter_set_id
    parameter_set_path(run.parameter_set_id).join(run.to_param)
  end

  def self.run_script_path(run)
    run = Run.find(run)
    prm = run.parameter_set_id
    parameter_set_path(run.parameter_set_id).join(run.to_param + '.sh')
  end

  def self.analyzable_path(analyzable)
    case analyzable
    when Run
      return run_path(analyzable.to_param)
    when ParameterSet
      return parameter_set_path(analyzable.to_param)
    else
      raise "not supported type"
    end
  end

  def self.analysis_run_path(analysis_run)
    analyzable = analysis_run.analyzable
    analyzable_path(analyzable).join(analysis_run.to_param)
  end

end
