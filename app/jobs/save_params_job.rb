class SaveParamsJob < ApplicationJob
  queue_as :default

  def perform(simulator_id, param_sets, num_runs, run_params_j, previous_num_ps, previous_num_runs)
    logger = Logger.new(File.join(Rails.root, 'log', 'resque.log'))
    logger.debug "Active job Save!"
    simulator = Simulator.find(simulator_id)
    run_params = ActionController::Parameters.new(run_params_j);
    logger.debug run_params.as_json.to_s
    logger.info "run_params.permitted?: #{run_params.permitted?}"
    run_params.permit!
    logger.info "run_params.permitted?: #{run_params.permitted?}"
    created = []
    param_sets.each do |param_ary|
      param = {}
      simulator.parameter_definitions.each_with_index do |defn, idx|
        param[defn.key] = param_ary[idx]
      end
      casted = ParametersUtil.cast_parameter_values(param, simulator.parameter_definitions)
      ps = simulator.parameter_sets.find_or_initialize_by(v: casted)
      if ps.persisted? or ps.save
        created << ps
      end
    end

    if created.empty?
      logger.error "No parameter_set was created!."
      return
    end

    new_runs = []
    num_runs.times do |i|
      created.each do |ps|
        next if ps.runs.count > i
        new_runs << ps.runs.build(run_params)
      end
    end
    ParameterSetsController.set_sequential_seeds(new_runs) if simulator.sequential_seed
    new_runs.map(&:save)
    logger.debug "runs save"

    num_created_ps = simulator.reload.parameter_sets.count - previous_num_ps
    num_created_runs = simulator.runs.count - previous_num_runs
    if num_created_ps == 0 and num_created_runs == 0
      logger.error "No parameter_sets or runs are created!"
    end

    logger.info "#{num_created_ps} ParameterSets and #{num_created_runs} runs were created"
  end

  private
  def to_o(json, klass)
    a = klass.new

    JSON.parse(json).each do |k, v|
      if (a.respond_to?("set_"+k.to_s))
         a.send("set_"+k.to_s, v)
      end
    end
    a
  end

end
