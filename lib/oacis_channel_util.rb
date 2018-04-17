module OacisChannelUtil

  def self.progressSaveTaskMessage(simulator, offset_num_ps=0)
    msg = ApplicationController.renderer.render(partial: 'simulators/save_ps_task_status', locals: {simulator: simulator, offset_num_ps: offset_num_ps})
    {save_task_progress: true, simulator_id: simulator.id.to_s, message: msg}
  end

  def self.createJobStatusMessage(job, status = nil)
    status ||= job.status

    ps = ParameterSet.where({id: job.parameter_set_id}) 
    return if ps.nil?
    status_counts = ParameterSet.runs_status_count_batch(ps)
    
    ws_mess = { :id => "#{job.id}",
                :status => "#{status}",
                :job_id => "#{job.job_id}",
                :real_time => "#{job.real_time}",
                :version => "#{job.version}",
                :ps_id => "#{job.parameter_set_id}",
                :ps_counts => status_counts[job.parameter_set_id]
              }
    ws_mess
  end
end
