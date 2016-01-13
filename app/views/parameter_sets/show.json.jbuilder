json.id @param_set.id.to_s
json.extract! @param_set, :v
json.simulator do
  json.id = @param_set.simulator.id.to_s
  json.name = @param_set.simulator.name
end
json.runs do
  json.array! @param_set.runs do |run|
    json.id run.id.to_s
    json.status run.status
  end
end
json.analyses do
  json.array! @param_set.analyses do |anl|
    json.id anl.id.to_s
    json.status anl.status
  end
end
