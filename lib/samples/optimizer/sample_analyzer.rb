require 'json'
require 'pp'

def load_data
  if File.exist?('_input.json')
    io = File.open('_input.json', 'r')
    return JSON.load(io)
  else
    return nil
  end
end

def save_data(h)
  File.open("_output.json", 'w') {|io| io.print h.to_json }
end

result = load_data
unless result.nil?
  h={"Fitness"=>result["result"]["Fitness"].first}
  save_data(h)
end
