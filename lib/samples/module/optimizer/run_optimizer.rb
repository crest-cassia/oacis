require 'json'

require_relative 'ga_simple.rb'

def load_input_data
  if File.exist?("_input.json")
    io = File.open('_input.json', 'r')
    parsed = JSON.load(io)
    return parsed
  end
end

input_data = load_input_data

if input_data.blank?
  STDERR.puts "_input.json is missing."
  exit(-1)
end

input_data["target"]=JSON.parse(input_data["target"])
input_data["operation"]=JSON.parse(input_data["operation"])

case input_data["operation"]["type"]
when "GA"
  @optimizer = GaSimple.new(input_data)
  @optimizer.run
else
  puts "No such optimizer."
end

