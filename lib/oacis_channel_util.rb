module OacisChannelUtil

  def self.createJobStatusMessage(job, status = nil)
    status ||= job.status;
    ws_mess = { :id => "#{job.id}",
                :status => "#{status}",
                :job_id => "#{job.job_id}",
                :real_time => "#{job.real_time}",
                :version => "#{job.version}"
              }
    ws_mess
  end
end
