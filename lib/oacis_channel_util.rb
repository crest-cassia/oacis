module OacisChannelUtil

  def self.progressSaveTaskMessage(simulator, offset_num_ps=0, offset_num_runs=0)
    msg = ApplicationController.renderer.render(partial: 'simulators/save_ps_task_status', locals: {simulator: simulator, offset_num_ps: offset_num_ps, offset_num_runs: offset_num_runs})
    {save_task_progress: true, simulator_id: simulator.id.to_s, message: msg}
  end

  def self.createJobStatusMessage(job, status = nil)
    status ||= job.status

    ps = ParameterSet.where({id: job.parameter_set_id})
    return if ps.first.nil?
    ps_status_counts = ParameterSet.runs_status_count_batch(ps)

    sim = Simulator.where({id: job.simulator_id})
    sim_status_counts = Simulator.runs_status_count_batch(sim)
    
    ws_mess = { :id => "#{job.id}",
                :status => "#{status}",
                :job_id => "#{job.job_id}",
                :real_time => "#{job.real_time}",
                :version => "#{job.version}",
                :updated_at => ApplicationController.helpers.distance_to_now_in_words(job.updated_at),
                :ps_id => "#{job.parameter_set_id}",
                :ps_counts => ps_status_counts[job.parameter_set_id],
                :ps_updated_at => ApplicationController.helpers.distance_to_now_in_words(ps.first.updated_at),
                :sim_id => "#{job.simulator_id}",
                :sim_counts => sim_status_counts[job.simulator_id],
                :sim_updated_at => ApplicationController.helpers.distance_to_now_in_words(sim.first.updated_at)
              }
    ws_mess
  end
end
