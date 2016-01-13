json.id @simulator.id.to_s
json.extract! @simulator,
              :name, :description, :command, :sequential_seed,
              :support_input_json, :support_mpi, :support_omp,
              :pre_process_script, :print_version_command
json.parameter_definitions do
  json.array! @simulator.parameter_definitions, :key, :type, :default, :description
end
json.executable_on do
  json.array! @simulator.executable_on do |host|
    json.id host.id.to_s
    json.name host.name
  end
end
json.analyzers do
  json.array! @simulator.analyzers do |azr|
    json.id azr.id.to_s
    json.name azr.name
  end
end
json.parameter_sets do
  json.array! @simulator.parameter_sets do |ps|
    json.id ps.id.to_s
    json.v ps.v
  end
end
