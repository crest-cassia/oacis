json.id @param_set.id.to_s
json.extract! @param_set, :v
json.directory @param_set.dir.to_s
json.simulator do
  json.id = @param_set.simulator.id.to_s
  json.name = @param_set.simulator.name
end
json.runs do
  json.array! @param_set.runs.only(:id, :status) do |run|
    json.id run.id.to_s
    json.status run.status
  end
end
json.analyses do
  json.array! @param_set.analyses.only(:id, :analyzer, :status, :parameters) do |anl|
    json.id anl.id.to_s
    json.analyzer anl.analyzer.name
    json.status anl.status
    json.parameters anl.parameters
  end
end
