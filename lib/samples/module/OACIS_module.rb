require 'pp'
require 'json'

require Rails.root.to_s+'/lib/samples/optimizer/optimizer.rb'

def input_data
  @input_data ||= fetch_input_data
end

def fetch_input_data
  input_data = load_input_data
  input_data
end

def load_input_data
  if File.exist?("_input.json")
    io = File.open('_input.json', 'r')
    parsed = JSON.load(io)
    parsed["target"]=JSON.parse(parsed["target"])
    parsed["operation"]=JSON.parse(parsed["operation"])
    return parsed
  end
end

if input_data.blank?
  puts "_input.json is missing."
  exit(-1)
end

case input_data["operation"]["module"]
when "optimization"
  case input_data["operation"]["type"]
  when "GA"
    opt = Optimizer.new(input_data)
    opt.run
  end
end