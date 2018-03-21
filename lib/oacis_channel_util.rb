module OacisChannelUtil

  def self.createJobStatusMessage(job, status = nil)
    status ||= job.status;

    ps = Simulator.where(job.parameter_set_id)
    pss = Mongoid::Criteria.new(ps)
    status_counts = ParameterSet.runs_status_count_batch(pss)
    
    ws_mess = { :id => "#{job.id}",
                :status => "#{status}",
                :job_id => "#{job.job_id}",
                :real_time => "#{job.real_time}",
                :version => "#{job.version}",
                :ps_count => "#{status_counts[job.parameter_set_id]}"
              }
    ws_mess
  end
end
