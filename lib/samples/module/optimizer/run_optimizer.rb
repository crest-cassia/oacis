require 'json'

require_relative 'ga_simple.rb'
require_relative 'pso_module.rb'

def load_input_data
  if File.exist?("_input.json")
    io = File.open('_input.json', 'r')
    parsed = JSON.load(io)
    return parsed
  end
end

input_data = load_input_data

if input_data.blank?
  raise "_input.json is missing."
end

input_data["_target"]=JSON.parse(input_data["_target"])

case input_data["_optimizer_type"]
when "GA"
  @optimizer = GaSimple.new(input_data)
  @optimizer.run
when "PSO"
  @optimizer = PsoModule.new(input_data)
  @optimizer.run
else
  raise "No such optimizer."
end

