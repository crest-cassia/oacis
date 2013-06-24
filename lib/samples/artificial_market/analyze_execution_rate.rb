require 'pp'
require 'json'

io = File.open('_input.json', 'r')
parsed = JSON.load(io)

io = File.open('data.dat', 'w')

[1,2,5,10,20,50,100].each do |ticksize_a|
  found = parsed["simulation_parameters"].find_all do |ps_id, v|
    v["TickSizeA"] == ticksize_a
  end
  sorted = found.sort_by {|ps_id, v| v["TickSizeB"] }
  sorted.each do |ps_id, v|
    x = v["TickSizeA"]
    y = v["TickSizeB"]
    pp parsed["result"][ps_id].first[1]
    result = parsed["result"][ps_id].first[1]["markets"].first["ExecutionRate"]["average"]
    io.puts "#{x} #{y} #{result}"
  end
  io.puts "" # empty line is necessary for gnuplot
end
io.flush
io.close

plt_file = 'plot.plt'
File.open(plt_file, 'w') do |pio|
  pio.puts <<EOS
set pm3d map
set title 'Execution Rate of Market A'
set xlabel 'ticksize A'
set ylabel 'ticksize B'
splot 'data.dat'
EOS
  pio.flush
end

system("/Users/murase/program/gists/1164203/epsplot.rb -f -n #{plt_file}")
system("convert plot.eps plot.png")
