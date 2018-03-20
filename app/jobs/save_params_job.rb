class SaveParamsJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exeption|
    logger = Logger.new(File.join(Rails.root, 'log', 'resque.log'))
    logger.debug "Exception: #{ exeption.class}"
    logger.debug "Exception: #{ exeption.message}"
    logger.debug "Exception: #{ exeption.backtrace}"
#     raise exeption
  end

  def perform(save_task_id, previous_num_ps, previous_num_runs)
    logger = Logger.new(File.join(Rails.root, 'log', 'resque.log'))
    logger.debug "save_task_id: " + save_task_id

    save_task = SaveTask.find(save_task_id)
    simulator_id = save_task.simulator_id
    param_sets = save_task.ps_param
    num_runs = save_task.run_num
    run_params_h = save_task.run_param    

    logger.debug "simulator_id: " + param_sets.to_s
    logger.debug "ps_param: " + param_sets.to_s
    logger.debug "run_params_h: " + run_params_h.to_s
    logger.debug "Active job Save!"
    simulator = Simulator.find(simulator_id)
    run_params = ActionController::Parameters.new(run_params_h);
    logger.debug run_params.as_json.to_s
    logger.debug "bef run_params.permitted? :" + run_params.permitted?.to_s
    run_params.permit!
    logger.debug "aft run_params.permitted? :" + run_params.permitted?.to_s
    created = []
    param_sets.each do |param_ary|
      save_task.reload
      logger.debug "Cancel Flag: " + save_task.cancel_flag.to_s
#      sleep(10)
      if save_task.cancel_flag
        logger.debug "save_task.destroy() couse Canceled."
        save_task.destroy()
        return
      end
      param = {}
      simulator.parameter_definitions.each_with_index do |defn, idx|
        param[defn.key] = param_ary[idx]
      end
      casted = ParametersUtil.cast_parameter_values(param, simulator.parameter_definitions)
      ps = simulator.parameter_sets.find_or_initialize_by(v: casted)
      if ps.persisted? or ps.save
        created << ps
        logger.debug "PS save"

        new_runs = []
        num_runs.times do |i|
          new_runs << ps.runs.build(run_params)
          logger.debug "runs build #{i}"
        end
        ParameterSetsController.set_sequential_seeds(new_runs) if simulator.sequential_seed
        new_runs.map(&:save)
        logger.debug "runs save"

        save_task.creation_size = save_task.creation_size - 1
        save_task.save
      end
    end

    if created.empty?
      logger.error "No parameter_set was created!."
      return
    end

    num_created_ps = simulator.reload.parameter_sets.count - previous_num_ps
    num_created_runs = simulator.runs.count - previous_num_runs
    if num_created_ps == 0 and num_created_runs == 0
      logger.error "No parameter_sets or runs are created!"
    end

    logger.debug "save_task.destroy() couse finished."
    save_task.destroy()

    logger.info "#{num_created_ps} ParameterSets and #{num_created_runs} runs were created"
  end
end
