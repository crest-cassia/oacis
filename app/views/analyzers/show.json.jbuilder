json.id @analyzer.id.to_s
json.extract! @analyzer,
              :name, :description, :type, :command,
              :auto_run, :files_to_copy,
              :support_input_json, :support_mpi, :support_omp,
              :pre_process_script, :print_version_command
json.parameter_definitions do
  json.array! @analyzer.parameter_definitions,
              :key, :type, :default, :description
end
json.executable_on do
  json.array! @analyzer.executable_on do |host|
    json.id host.id.to_s
    json.name host.name
  end
end
