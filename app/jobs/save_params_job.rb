class SaveParamsJob < ApplicationJob
  queue_as :default
  rescue_from(StandardError) do |exeption|
  end

  def perform(save_task_id, previous_num_ps, previous_num_runs)
    save_task = SaveTask.find(save_task_id)
    simulator_id = save_task.simulator_id
    param_sets = save_task.ps_params
    num_runs = save_task.num_runs
    run_params_h = save_task.run_param    
    simulator = Simulator.find(simulator_id)
    run_params = ActionController::Parameters.new(run_params_h);
    run_params.permit!
    created = []
    param_sets.each do |param_ary|
      save_task.reload
#      sleep(10)
      if save_task.cancel_flag
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
        new_runs = []
        num_runs.times do |i|
          new_runs << ps.runs.build(run_params)
        end
        ParameterSetsController.set_sequential_seeds(new_runs) if simulator.sequential_seed
        new_runs.each do |run|
          run.save
        end

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

    save_task.destroy()

    logger.info "#{num_created_ps} ParameterSets and #{num_created_runs} runs were created"
  end
end
