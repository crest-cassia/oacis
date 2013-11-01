require 'json'

require_relative 'optimizer.rb'

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

Optimizer.new(input_data).run
