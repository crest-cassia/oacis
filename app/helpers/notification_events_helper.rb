module NotificationEventsHelper
  def generate_all_jobs_in_simulator_finished_message(job)
    simulator_id = job.simulator.id
    id_link = link_to(shortened_id(simulator_id), simulator_url(simulator_id))

    return "All #{job.class} in SimulatorID #{id_link} finished."
  end

  def generate_all_jobs_in_param_set_finished_message(job)
    param_set_id = job.parameter_set.id
    id_link = link_to(shortened_id(param_set_id), parameter_set_url(param_set_id))

    return "All #{job.class} in ParameterSetID #{id_link} finished."
  end

  def generate_single_job_finished_message(job)
    id_link = link_to(shortened_id(job.id), send("#{job.class.name.underscore}_url", job))

    return "#{job.class}ID #{id_link} #{job.status}."
  end

  protected

  def default_url_options
    { host: Oacis::Application.config.user_config['oacis_host'] || 'localhost:3000' }
  end
end
