require 'pp'
require 'json'

def traverse_result(results)
  result = results.first
  case result
  when Hash
    output = Hash.new
    result.keys.each do |key|
      mapped = results.map {|h| h[key] }
      output[key] = traverse_result(mapped)
    end
    output
  when Array
    output = []
    result.times do |i|
      mapped = results.map {|a| a[i]}
      output[i] = traverse_result(mapped)
    end
    output
  when Float, Integer
    ave, err = error_analysis(results)
    {average: ave, error: err}
  else
    nil
  end
end

def error_analysis(data)
  n = data.size
  ave = data.inject(:+).to_f / n
  err = nil
  err = Math.sqrt( data.map {|x| (x-ave)*(x-ave) }.inject(:+) / (n*(n-1)) ) if n > 1
  return ave, err
end

parsed = JSON.load( File.open('_input.json') )
results = []
parsed["result"].each_pair {|run_id, result| results << result }
output = traverse_result(results)
File.open("_output.json", 'w') {|io| io.print output.to_json }