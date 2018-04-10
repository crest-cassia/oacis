module OacisChannelUtil

  def self.createJobStatusMessage(job, status = nil)
    status ||= job.status;

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
