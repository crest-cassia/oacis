require 'json'

require_relative 'pso.rb'

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
input_data["_managed_parameters"]=JSON.parse(input_data["_managed_parameters"])

PsoModule.new(input_data).run

