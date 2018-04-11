class SaveParamsJob < ApplicationJob
  queue_as :default
  rescue_from(StandardError) do |exeption|
    Resque.logger.error exeption
  end

  def perform(save_task_id)
    save_task = SaveTask.find(save_task_id)
    simulator_id = save_task.simulator_id
    param_sets = save_task.ps_params
    num_runs = save_task.num_runs
    run_params_h = save_task.run_param? ? save_task.run_param : {}
    simulator = Simulator.find(simulator_id)
    run_params = ActionController::Parameters.new();
    if num_runs > 0
      run_params = ActionController::Parameters.new(run_params_h);
      run_params.permit!
    end
    created = []
    param_sets.each do |param_ary|
      save_task.reload
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
        new_runs.each {|run| run.save}

        save_task.creation_size = save_task.creation_size - 1
        save_task.save
      end
      sleep(2)
    end

    if created.empty?
      Resque.logger.error "No parameter_set was created!."
      save_task.destroy()
      return
    end
    save_task.destroy()
  end
end
