require 'json'

require_relative '/home/t-uchitane/git/cassia/lib/samples/module/optimizer/ga_undx/ga_undx.rb'

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

GaUndx.new(input_data).run
