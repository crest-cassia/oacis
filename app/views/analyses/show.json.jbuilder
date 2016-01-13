json.id @analysis.id.to_s
json.analyzer do
  json.id @analysis.analyzer.id.to_s
  json.name @analysis.analyzer.name
end
json.extract! @analysis,
              :status, :parameters, :job_script, :host_parameters, :mpi_procs, :omp_threads,
              :priority, :job_id, :submitted_at, :error_messages,
              :hostname, :cpu_time, :real_time, :started_at, :finished_at,
              :included_at, :result
json.submitted_to do
  s = @analysis.submitted_to
  if s
    json.id s.id.to_s
    json.name s.name
  else
    json.null!
  end
end
json.analyzable do
  json.id @analysis.analyzable.id.to_s
end
