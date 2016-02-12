json.id @run.id.to_s
json.simulator do
  json.id @run.simulator.id.to_s
  json.name @run.simulator.name
end
json.directory @run.dir.to_s
json.extract! @run,
              :status, :seed, :job_script, :host_parameters, :mpi_procs, :omp_threads,
              :priority, :job_id, :submitted_at, :error_messages,
              :hostname, :cpu_time, :real_time, :started_at, :finished_at,
              :included_at, :result
json.submitted_to do
  s = @run.submitted_to
  if s
    json.id s.id.to_s
    json.name s.name
  else
    json.null!
  end
end
json.parameter_set do
  json.id @run.parameter_set.id.to_s
  json.v @run.parameter_set.v
end
json.analyses do
  json.array! @run.analyses.only(:id, :analyzer, :status, :parameters) do |anl|
    json.id anl.id.to_s
    json.analyzer anl.analyzer.name
    json.status anl.status
    json.parameters anl.parameters
  end
end
