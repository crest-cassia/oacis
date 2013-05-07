require 'pp'
require 'json'

def average_of_result(input_files)
  sum = 0.0
  n = input_files.count
  input_files.each do |input_file|
    sum += File.open( input_file, 'r').readlines[0].to_f
  end
  average = sum / n

  sum = 0.0  
  input_files.each do |input_file|
    val = File.open( input_file, 'r').readlines[0].to_f
    sum += (val - average) * (val - average)
  end
  error = Math.sqrt(sum / n.to_f / (n-1).to_f)

  return average, error
end

inputs = Dir.glob("_input/*/result.txt")
pp inputs

ave, err = average_of_result(inputs)
result = {"average num cars" => ave, "error" => err}
File.open('_output.json','w') do |io|
  io.puts JSON.pretty_generate(result)
end
